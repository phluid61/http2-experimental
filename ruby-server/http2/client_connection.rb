
require_relative 'connection'

class HTTP2_ClientConnection < HTTP2_Connection

	def start
		raise "already shutdown" if @shutdown
		raise "already started" if @started
		@started = true

		# Send standard header
		STDERR.puts "[#{Time.now}] writing preface..."
		@peer.write HTTP2_PREFACE

		STDERR.puts "[#{Time.now}] starting pump..."
		Thread.new do
			super
		end
	end

end
