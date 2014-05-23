
require_relative 'frame/data'
require_relative 'frame/headers'
require_relative 'frame/priority'
require_relative 'frame/rst_stream'
require_relative 'frame/settings'
require_relative 'frame/settings_ack'
require_relative 'frame/push_promise'
require_relative 'frame/ping'
require_relative 'frame/goaway'
require_relative 'frame/window_update'
require_relative 'frame/continuation'
require_relative 'frame/altsvc'

class HTTP2_Frame

	TYPES = [
		:DATA, :HEADERS, :PRIORITY, :RST_STREAM, :SETTINGS,
		:PUSH_PROMISE, :PING, :GOAWAY, :WINDOW_UPDATE,
		:CONTINUATION, :ALTSVC
	]

	def self._read io, bytes
		result = ''
		while bytes > 0
			buf = io.read bytes
			raise "buffer underrun (expected #{bytes})" unless buf
			result << buf
			bytes -= buf.bytesize
		end
		result
	end

	def self.recv_from io
		# Read the header
		packed = self._read io, 8
		length, type, flags, stream_id = packed.unpack 'S>CCL>'
		length &= 0x3fff
		stream_id &= 0x7fffffff

		# Read the payload (if any)
		payload = length > 0 ? self._read(io, length) : ''

		# Construct an object and return it
		self.new type, flags: flags, stream_id: stream_id, payload: payload
	end

	def initialize type, flags: 0, stream_id: 0, payload: nil
		self.type = type
		self.flags = flags
		self.stream_id = stream_id
		self.payload = payload
	end

	attr_reader :type, :flags, :stream_id, :payload
	def length
		@payload.bytesize
	end
	def type_symbol
		TYPES[@type]
	end

	def type= t
		case t
		when :DATA,          0; @type =  0
		when :HEADERS,       1; @type =  1
		when :PRIORITY,      2; @type =  2
		when :RST_STREAM,    3; @type =  3
		when :SETTINGS,      4; @type =  4
		when :PUSH_PROMISE,  5; @type =  5
		when :PING,          6; @type =  6
		when :GOAWAY,        7; @type =  7
		when :WINDOW_UPDATE, 8; @type =  8
		when :CONTINUATION,  9; @type =  9
		when :ALTSVC,       10; @type = 10
		else
			raise ArgumentError
		end
	end
	def flags= f
		raise ArgumentError if f < 0 || f > 255
		@flags = f
	end
	def stream_id= sid
		raise ArgumentError if sid < 0 || sid > 2**31
		@stream_id = sid
	end
	def payload= p
		p = p.to_s
		raise ArgumentError if p.bytesize > 2**14
		@payload = p
	end

	def << bytes
		raise PayloadTooLong if @payload.bytesize + bytes.to_s.bytesize > 2**14
		@payload << bytes
		self
	end

	def to_s
		[length, type, flags, stream_id].pack('S>CCL>') + @payload
	end

end

