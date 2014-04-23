
require 'socket'

begin
	raise "Invalid arguments" unless ARGV.length == 1
	port = Integer(ARGV[0])

	s = TCPSocket.new 'localhost', port
	# start a response pump
	Thread.new do
		loop do
			begin
				chunk = s.read(4096)
				puts s
			rescue Exception => e
				p e
				puts e.backtrace.map{|b| "\t#{b}" }
			end
			break if s.closed?
		end
	end

	# feed it the script
	# 1. preface, initial settings, ack
	s.write "PRI * HTTP/2.0\x0D\x0A\x0D\x0ASM\x0D\x0A\x0D\x0A"
	s.write [0,0x4,0,0].pack('S>CCL>')
	s.write [0,0x4,0,0x1].pack('S>CCL>')

	# 2. get /
	payload = ":method:get\x0D\x0A:path:/"
	s.write [payload.bytesize,0x1,1,0x1|0x4].pack('S>CCL>')+payload

	# 3. post / foo
	payload = ":method:post\x0D\x0A:path:/"
	s.write [payload.bytesize,0x1,1,0x4].pack('S>CCL>')+payload
	payload = "foo"
	s.write [payload.bytesize,0x0,3,0x1].pack('S>CCL>')

	# 4. ping rofl*
	payload = "rofl"*16
	s.write [payload.bytesize,0x6,0,0x0].pack('S>CCL>')+payload

	# 5. goaway
	payload = [3,0].pack('L>L>')+"This is the end... beautiful friend"
	s.write [payload.bytesize,0x7,0,0x0].pack('S>CCL>')+payload

rescue Exception => e
	p e
	puts e.backtrace.map{|b| "\t#{b}" }
end
