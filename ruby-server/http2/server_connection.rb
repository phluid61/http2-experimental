
require_relative 'connection'

class HTTP2_ServerConnection < HTTP2_Connection

	def start
		raise "already shutdown" if @shutdown
		raise "already started" if @started
		@started = true

		# Receive standard header
		intro = @peer.read(24)
		if intro != HTTP2_PREFACE
			STDERR.puts "[#{Time.now}] #{@peer.inspect}: bad preface"
			#STDERR.puts intro.each_byte.map{|b|'%02X' % b}.join, intro.inspect
			goaway :PROTOCOL_ERROR, debug_data: intro
			return
		end
		STDERR.puts "[#{Time.now}] #{@peer.inspect}: good preface"

		super
	end

end
