# Encoding: ascii-8bit

require 'hashmap'
require_relative 'core'

class HPACK_Context

	INDEXED_BIT         = 0x80
	LITERAL_INDEXED_BIT = 0x40
	CONTEXT_UPDATE_BIT  = 0x20
	LITERAL_NOINDEX_BIT = 0x10

	CONTEXT_UPDATE = 0x20
	FLUSH_REFSET = CONTEXT_UPDATE|0x10
	RESIZE_TABLE = CONTEXT_UPDATE|0x00

	def initialize max=4096
		@reference_set = ReferenceSet.new
		@header_table = HeaderTable.new(max) do |e|
			@reference_set.drop e
		end
		@block = []
		@bytes = ''
	end

	#
	# Begin a new header block.
	#
	def begin_block
		@block = []
		self
	end

	#
	# Get the current header block.
	#
	def block
		(@block + @reference_set.to_a).uniq
	end

	#
	# Receive bytes from the wire.
	#
	def recv bytes
		bytes = bytes.to_s
		while bytes.bytesize > 0
			b = bytes.unpack('C').first
			if b & INDEXED_BIT == INDEXED_BIT
				_, idx, bytes = HPACK.decode_int bytes, prefix_bits: 7
				recv_index idx
			elsif b & LITERAL_INDEXED_BIT == LITERAL_INDEXED_BIT
				name, value, bytes = _recv_indexed bytes, 6
				recv_literal name, value
			elsif b & CONTEXT_UPDATE_BIT == CONTEXT_UPDATE_BIT
				_, max, bytes = HPACK.decode_int bytes, prefix_bits: 4
				if b & FLUSH_REFSET == FLUSH_REFSET
					raise "Invalid FLUSH_REFSET (rest=#{max}, expected 0)" if max != 0
					flush_reference_set
				else # RESIZE_TABLE
					resize_table max
				end
			elsif b & LITERAL_NOINDEX_BIT == LITERAL_NOINDEX_BIT
				name, value, bytes = _recv_indexed bytes, 4
				recv_literal name, value, index: false
			else
				name, value, bytes = _recv_indexed bytes, 4
				recv_literal name, value, index: nil
			end
		end
		self
	end
	def _recv_indexed bytes, prefix
		_, idx, bytes = HPACK.decode_int bytes, prefix_bits: prefix
		if idx == 0
			name, bytes = HPACK.decode_string bytes
		else
			name = @header_table[idx].name
		end
		value, bytes = HPACK.decode_string bytes
		[name, value, bytes]
	end

	def recv_index i
		e = @header_table[i]
		if !@reference_set.drop(e)
			if i > @header_table.length
				idx = @header_table.add_entry e
				@reference_set << e if idx
			else
				@reference_set << e
			end
			@block << e
			e
		end
	end

	def recv_literal name, value, index: true
		e = HeaderTable::Entry.new name, value
		if index
			idx = @header_table.add_entry e
			@reference_set << e if idx
		end
		@block << e
		e
	end

	#
	# Begin a new header block.
	#
	def begin_bytes
		@bytes = ''
		self
	end

	#
	# Get the current header block.
	#
	def bytes
		@bytes.dup
	end

	#
	# FIXME: should this add anything to a table?
	#
	# @param String name
	# @param String value if nil, just drop the name
	#
	def drop name, value=nil
		if value
			i = @header_table.find(name, value)
		else
			i = @header_table.find_name name
		end
		raise "no such item in header table" unless i
		e = @reference_set.drop(@header_table[i])
		raise "no such item in reference set" unless e
		@bytes << HPACK.encode_int(i, prefix_bits: 7, prefix: INDEXED_BIT) if i
		self
	end

	#
	# FIXME: should this add anything to a table?
	#
	# @param String name
	# @param String value
	# @param index: true=index, nil=don't index, false=never index
	# @return bytes to pack into a HEADERS payload
	#
	def send name, value, index: true
		if index && (i = @header_table.find(name, value)) && (e = @header_table[i]) && !@reference_set.include?(e)
			@reference_set << e
			@bytes << HPACK.encode_int(i, prefix_bits: 7, prefix: INDEXED_BIT)
		else
			e = HeaderTable::Entry.new name, value
			if index
				p = LITERAL_INDEXED_BIT
				b = 6
			elsif index.nil?
				p = 0
				b = 4
			else
				p = LITERAL_NOINDEX_BIT
				b = 4
			end
			i = @header_table.find_name(name)
			if i
				@bytes << HPACK.encode_int(i, prefix_bits: b, prefix: p)
			else
				@bytes << [p].pack('C') << HPACK.encode_string(name)
			end
			if index
				idx = @header_table.add_entry e
				@reference_set << e if idx
			end
			@bytes << HPACK.encode_string(value)
		end
		self
	end

	#
	# @return bytes to pack into a HEADERS payload
	#
	def flush_reference_set
		@reference_set.flush
		@bytes << [FLUSH_REFSET].pack('C')
		self
	end

	#
	# @return bytes to pack into a HEADERS payload
	#
	def resize_table max
		@header_table.max = max
		@bytes << HPACK.encode_int(max, prefix_bits: 4, prefix: RESIZE_TABLE)
		self
	end

	class ReferenceSet
		include Enumerable
		def initialize
			@refs = {}
		end
		def << e
			@refs[e] = e if e
			self
		end
		def include? e
			@refs[e]
		end
		def drop e
			@refs.delete e
		end
		def flush
			@refs = {}
		end
		def each &block
			@refs.each_key &block
		end
	end

	class HeaderTable
		class Entry
			def initialize name, value
				@name = name.freeze
				@value = value.freeze
				@size = @name.bytesize + @value.bytesize + 32
			end
			attr_reader :name, :value, :size
			def to_s
				if @name.downcase == 'cookie'
					"#{@name}: #{@value.gsub "\0", '; '}"
				else
					"#{@name}: #{@value}"
				end
			end
		end

		def initialize max=4096, &on_evict
			@max = max
			@table = []
			@size = 0
			@on_evict = on_evict
		end
		attr_reader :max, :size

		def length
			@table.length
		end

		def max= max
			@max = max
			_evict
			self
		end

		#
		# Add a name:value pair to the start of the table.
		#
		# @return the index of the new entry, or nil if it's too big.
		#
		def add name, value
			add_entry Entry.new(name, value)
		end

		#
		# Add a name:value pair to the start of the table.
		#
		# @return the index of the new entry, or nil if it's too big.
		#
		def add_entry e
			__evict( @max - e.size )
			if e.size < @max
				@table.unshift e
				@size += e.size
				@table.length
			end
		end

		def __evict max=nil
			max ||= @max
			max = 0 if max < 0
			while @size > max
				e = @table.pop
				@size -= e.size
				@on_evict.call(e) if @on_evict
			end
		end
		private :__evict

		def find_name name
			name = name.downcase
			idx = @table.find_index {|e| e.name.downcase == name }
			idx or StaticTable.find_index {|e| e.name == name }
			idx and idx+1
		end

		def find name, value
			name = name.downcase
			idx = @table.find_index {|e| e.name.downcase == name && e.value == value }
			idx or StaticTable.find_index {|e| e.name == name && e.value == value }
			idx and idx+1
		end

		def [] i
			i -= 1
			raise ArgumentError, "index too small" if i < 0
			return @table[i] if i < @table.length
			i -= @table.length
			return StaticTable[i] if i < StaticTable.length
			raise ArgumentError, "index too large"
		end

		StaticTable = [
			Entry.new(':authority', ''),
			Entry.new(':method', 'GET'),
			Entry.new(':method', 'POST'),
			Entry.new(':path', '/'),
			Entry.new(':path', '/index.html'),
			Entry.new(':scheme', 'http'),
			Entry.new(':scheme', 'https'),
			Entry.new(':status', '200'),
			Entry.new(':status', '204'),
			Entry.new(':status', '206'),
			Entry.new(':status', '304'),
			Entry.new(':status', '400'),
			Entry.new(':status', '404'),
			Entry.new(':status', '500'),
			Entry.new('accept-charset', ''),
			Entry.new('accept-encoding', ''),
			Entry.new('accept-language', ''),
			Entry.new('accept-ranges', ''),
			Entry.new('accept', ''),
			Entry.new('access-control-allow-origin', ''),
			Entry.new('age', ''),
			Entry.new('allow', ''),
			Entry.new('authorization', ''),
			Entry.new('cache-control', ''),
			Entry.new('content-disposition', ''),
			Entry.new('content-encoding', ''),
			Entry.new('content-language', ''),
			Entry.new('content-length', ''),
			Entry.new('content-location', ''),
			Entry.new('content-range', ''),
			Entry.new('content-type', ''),
			Entry.new('cookie', ''),
			Entry.new('date', ''),
			Entry.new('etag', ''),
			Entry.new('expect', ''),
			Entry.new('expires', ''),
			Entry.new('from', ''),
			Entry.new('host', ''),
			Entry.new('if-match', ''),
			Entry.new('if-modified-since', ''),
			Entry.new('if-none-match', ''),
			Entry.new('if-range', ''),
			Entry.new('if-unmodified-since', ''),
			Entry.new('last-modified', ''),
			Entry.new('link', ''),
			Entry.new('location', ''),
			Entry.new('max-forwards', ''),
			Entry.new('proxy-authenticate', ''),
			Entry.new('proxy-authorization', ''),
			Entry.new('range', ''),
			Entry.new('referer', ''),
			Entry.new('refresh', ''),
			Entry.new('retry-after', ''),
			Entry.new('server', ''),
			Entry.new('set-cookie', ''),
			Entry.new('strict-transport-security', ''),
			Entry.new('transfer-encoding', ''),
			Entry.new('user-agent', ''),
			Entry.new('vary', ''),
			Entry.new('via', ''),
			Entry.new('www-authenticate', ''),
		]
	end

end
