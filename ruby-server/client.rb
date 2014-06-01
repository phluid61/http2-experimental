
require_relative 'http2/client'

# So it can be tweaked at the command line
$MAX_CONCURRENT_STREAMS = 10

begin
	raise "Invalid arguments" unless ARGV.length == 1
	port = Integer(ARGV[0])

	HTTP2_Client.new('localhost', port).start
rescue Exception => e
	p e
	puts e.backtrace.map{|b| "\t#{b}" }
end
