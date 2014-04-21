
require_relative '../frame'
require_relative 'settings_ack'

class HTTP2_Frame_SETTINGS

	FLAG_ACK = 0x1

	PARAMETERS = [
		nil, :SETTINGS_HEADER_TABLE_SIZE, :SETTINGS_ENABLE_PUSH,
		:SETTINGS_MAX_CONCURRENT_STREAMS, :SETTINGS_INITIAL_WINDOW_SIZE,
		:SETTINGS_ACCEPT_COMPRESSION,
	]

	def self.from f
		raise ArgumentError unless f.type_symbol == :SETTINGS
		raise PROTOCOL_ERROR unless f.stream_id == 0
		if f.flags & FLAG_ACK == FLAG_ACK
			raise FRAME_SIZE_ERROR unless f.length == 0
			HTTP2_Frame_SETTINGS_ACK.new
		else
			raise PROTOCOL_ERROR if f.length % 5 != 0
			buf = f.payload
			hsh = {}
			until buf.empty?
				id, val, buf = buf.unpack 'CL<a*'
				hsh[id] = val
			end
			self.new hsh
		end
	end

	def initialize settings={}
		@settings = {}
		self.settings = settings
		@frame = HTTP2_Frame.new :SETTINGS, payload: __serialize
	end

	def settings
		@settings.dup
	end

	def settings= hash
		hash.each_pair do |id, v|
			__set id, v
		end
		@frame.payload = __serialize if @frame
	end
	def set id, v
		__set id, v
		@frame.payload = __serialize if @frame
	end
	alias :[]= :set

	private	def __set id, v
		case id
		when :SETTINGS_HEADER_TABLE_SIZE, :HEADER_TABLE_SIZE, 1
			id = 1
		when :SETTINGS_ENABLE_PUSH, :ENABLE_PUSH, 2
			id = 2
			# MUST be 0 or 1
			raise ArgumentError unless v == 0 || v == 1
		when :SETTINGS_MAX_CONCURRENT_STREAMS, :MAX_CONCURRENT_STREAMS, 3
			id = 3
		when :SETTINGS_INITIAL_WINDOW_SIZE, :INITIAL_WINDOW_SIZE, 4
			id = 4
			# MUST NOT exceed 2**31-1
			raise ArgumentError if v >= 2**31
		when :SETTINGS_ACCEPT_COMPRESSION, :ACCEPT_COMPRESSION, 5
			id = 5
			# MUST be 0 or 1
			raise ArgumentError unless v == 0 || v == 1
		else
			raise ArgumentError
		end

		@settings[id] = v
	end

	def each &blk
		@settings.each_pair{|k,v| yield (PARAMETERS[k] || k), v }
	end

	def to_s
		@frame.to_s
	end

	def __serialize
		s = ''
		@settings.each_pair do |id, v|
			s << [id, v].pack('CL<')
		end
		s
	end

	include Enumerable

end

