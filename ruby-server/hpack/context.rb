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
	end

	#
	# @param String name
	# @param String value
	# @param index: true=index, nil=don't index, false=never index
	#
	def send name, value, index: true
		if index
			i = @header_table.find(name, value)
			return send_index(i) if i
		end
		send_literal name, value, index: index
	end

	def send_index i
		HPACK.encode_int i, prefix_bits: 7, prefix: INDEXED_BIT
	end
	# TODO: the recv that invokes this
	def recv_index i
		e = @header_table[i]
		if !@reference_set.drop(e)
			if i > @header_table.length
				idx = @header_table.add_entry e
				@reference_set << @header_table[idx] if idx
			else
				@reference_set << @header_table[i]
			end
			e
		end
	end

	#
	# FIXME: should this add anything to a table?
	#
	# @param String name
	# @param String value
	# @param index: true=index, nil=don't index, false=never index
	#
	def send_literal name, value, index: true
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
			bytes = HPACK.encode_int i, prefix_bits: b, prefix: p
		else
			bytes = [p].pack('C')
			bytes << HPACK.encode_string(name)
		end
		bytes << HPACK.encode_string(value)
	end
	# TODO: the recv that invokes this (and possibly pulls the name out of the table)
	def recv_literal name, value, index: true
		e = HeaderTable::Entry.new name, value
		if index
			idx = @header_table.add_entry e
			if idx
				@reference_set << @header_table[i]
			end
		end
		e
	end

	def reference_set &block
		@reference_set.each &block
	end

	def flush_reference_set
		@reference_set.flush
		[FLUSH_REFSET].pack('C')
	end

	def resize_table max
		@header_table.max = max
		HPACK.encode_int max, prefix_bits: 4, prefix: RESIZE_TABLE
	end

	class ReferenceSet
		def initialize
			@refs = {}
		end
		def << e
			@refs[e] = e if e
			self
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
		end

		def initialize max=4096, &on_evict
			@max = max
			@table = []
			@size = 0
			@on_evit = on_evict
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
			_evict( @max - e.size )
			if e.size < @max
				@table.unshift e
				@size += e.size
				@table.length
			end
		end

		def __evict max=nil
			max ||= @max
			while @size > max
				e = @table.pop
				@size -= e.size
				@on_evict.call(e)
			end
		end
		private :__evict

		def find_name name
			name = name.downcase
			idx = @table.find_index {|e| e.name.downcase == name }
			idx or StaticTable.find_index {|e| e.name == name }
		end

		def find name, value
			name = name.downcase
			idx = @table.find_index {|e| e.name.downcase == name && e.value == value }
			idx or StaticTable.find_index {|e| e.name == name && e.value == value }
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
