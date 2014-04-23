
require_relative '../frame'
require_relative '../error'

class HTTP2_Frame_ALTSVC

	def self.from f
		raise ArgumentError unless f.type_symbol == :ALTSVC
		payload = f.payload
		maxage, port, r, pl = payload.unpack('L>S>CC')
		pid = payload.byteslice(8,pl)
		payload = payload.byteslice(8+pl,-1)
		hl = payload.unpack('C').first
		host = payload.byteslice(1,hl)
		origin = payload.byteslice(1+hl,-1)
		origin = nil if origin.empty?
		self.new maxage, port, pid, host, origin: origin, stream_id: f.stream_id
	end

	def initialize max_age, port, protocol_id, host, origin: nil, stream_id: 0
		self.max_age = max_age
		self.port = port
		self.protocol_id = protocol_id
		self.host = host
		self.origin = origin
		@frame = HTTP2_Frame.new :ALTSVC, stream_id: stream_id, payload: __serialize
	end

	attr_reader :max_age, :port, :protocol_id, :host, :origin

	def stream_id
		@frame.stream_id
	end

	def max_age= ma
		raise ArgumentError if ma < 0 || ma >= 2**32
		@max_age = ma
		@frame.payload = __serialize if @frame
	end

	def port= p
		raise ArgumentError if p < 0 || p >= 2**16
		@port = p
		@frame.payload = __serialize if @frame
	end

	def protocol_id= pid
		raise ArgumentError if pid.bytesize > 0xFF
		@protocol_id = pid
		@frame.payload = __serialize if @frame
	end

	def host= h
		raise ArgumentError if h.bytesize > 0xFF
		@host = h
		@frame.payload = __serialize if @frame
	end

	def origin= o
		@origin = o
		@frame.payload = __serialize if @frame
	end

	def stream_id= sid
		@frame.stream_id = sid
	end

	def to_s
		@frame.to_s
	end

	def __serialize
		[@max_age,@port,0,@protocol_id.bytesize,@protocol_id,@host.bytesize,@host,@origin.to_s].pack 'L>S>CCa*Ca*a*'
	end

end

