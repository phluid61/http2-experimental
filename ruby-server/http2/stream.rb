
require_relative 'connection'
require_relative 'error'

class HTTP2_Stream

	def initialize id, conn, local=false
		raise ArgumentError if id < 0 || id > 0x7FFF_FFFF
		raise TypeError unless conn.is_a? HTTP2_Connection
		@id = id
		@conn = conn
		@local = !!local

		@state = :idle
		@accept_continuation = false

		@headers_recvd = ''
		@data_recvd = ''
	end

	attr_reader :id, :conn, :state

	def local?
		@local
	end

	def recv_headers f, *cs
		case @state
		when :idle, :open
			@state = (f.end_stream? ? :half_closed_remote : :open)
		# FIXME: this goes in the #send_headers function!
#		when :reserved_local
#			next_state = :half_closed_remote
#			if f.end_headers?
#				@state = next_state
#			else
#				@accept_continuation = next_state
#			end
		else
			raise PROTOCOL_ERROR
		end
		@headers_recvd << f.fragment
		cs.each do |c|
			@headers_recvd << c.fragment
		end
		emit if f.end_segment? || f.end_stream?
	end

	def recv_data f
		raise PROTOCOL_ERROR unless @state == :open
		if f.end_stream?
			@state = :half_closed_remote
		end
		@data_recvd << f.data
		emit if f.end_segment? || f.end_stream?
	end

	def recv_priority f
		# TODO
	end

	def recv_rst_stream f
		raise PROTOCOL_ERROR if @state == :idle
		# TODO
	end

	def emit
		# TODO: actually, you know, *emit* it...
		@headers_recvd = ''
		@data_recvd = ''
	end

end
