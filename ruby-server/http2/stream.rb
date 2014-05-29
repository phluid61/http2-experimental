
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

	def recv_headers block, f, *cs
		case @state
		when :idle, :open
			@state = (f.end_stream? ? :half_closed_remote : :open)
		when :reserved_remote
			# FIXME: can this go to fully closed with end_stream?
			@state = :half_closed_local
		else
			raise PROTOCOL_ERROR
		end
		#@headers_recvd << f.fragment
		#cs.each do |c|
		#	@headers_recvd << c.fragment
		#end
		@headers_recvd << block.map(&:to_s).join("\r\n")
		emit_message if f.end_segment? || f.end_stream?
	end

	def recv_push_promise block, f, *cs
		case @state
		when :idle
			@state = :reserved_remote
		else
			raise PROTOCOL_ERROR
		end
		#@headers_recvd << f.fragment
		#cs.each do |c|
		#	@headers_recvd << c.fragment
		#end
		@headers_recvd << block.map(&:to_s).join("\r\n")
		emit_pp # warn the API that there's a PP incoming
	end

	def recv_data f
		raise PROTOCOL_ERROR unless @state == :open
		if f.end_stream?
			@state = :half_closed_remote
		end
		@data_recvd << f.data
		emit_message if f.end_segment? || f.end_stream?
	end

	def recv_priority f
		# TODO
	end

	def recv_window_update f
		# TODO
	end

	def recv_rst_stream f
		raise PROTOCOL_ERROR if @state == :idle
		# TODO
	end

	def recv_altsvc f
		# TODO
	end

	def emit_message
		@conn.handle_message @id, @headers_recvd, @data_recvd
		@headers_recvd = ''
		@data_recvd = ''
	end

	def emit_pp
		@conn.handle_pp @id, @headers_recvd
	end

end
