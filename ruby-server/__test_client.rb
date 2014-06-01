# Encoding: ascii-8bit

require 'json'
require 'socket'

begin
	raise "Invalid arguments" unless ARGV.length == 2
	port = Integer(ARGV[0])
	script = ARGV[1]

	hsh = JSON.parse(File.open(script){|f|f.read})

	s = TCPSocket.new 'localhost', port
	# start a response pump
	t = Thread.new do
		loop do
			chunk = nil
			begin
				chunk = s.read(4096)
				p chunk if chunk
			rescue Exception => e
				p e
				puts e.backtrace.map{|b| "\t#{b}" }
			end
			break if s.closed? || chunk.nil?
		end
	end

	# preface, initial settings, ack
	s.write "PRI * HTTP/2.0\x0D\x0A\x0D\x0ASM\x0D\x0A\x0D\x0A"
	s.write [0,0x4,0x0,0].pack('S>CCL>')
	s.write [0,0x4,0x1,0].pack('S>CCL>')

	hsh['cases'].each_with_index do |c,i|
		# print expectation:
		puts "#{i*2+1}:"
		c['headers'].each do |h|
			h.each_pair do |k,v|
				puts "  #{k}: #{v}"
			end
		end
		# send serialisation:
		payload = c['wire'].scan(/../).map{|s|s.to_i 16}.pack('C*')
		s.write [payload.bytesize,0x1,0x1|0x4,i*2+1].pack('S>CCL>')+payload
	end

	# goaway
	payload = [3,0].pack('L>L>')+"This is the end... beautiful friend"
	s.write [payload.bytesize,0x7,0x0,0].pack('S>CCL>')+payload

	t.join

rescue Exception => e
	p e
	puts e.backtrace.map{|b| "\t#{b}" }
end
