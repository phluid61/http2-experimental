
class Object
	def foobar *_
	end
end

$counter = 0

class Array
	def foo
		unless @foo
			@foo = $counter
			$counter += 1
		end
		@foo
	end
	def bar hsh
#		if rand(2) == 0
			hsh[foo] = map do |e|
				if e.is_a? Array
					e.foo
				elsif e.nil?
					0x8100
				else
					e | 0x8000
				end
			end
#		else
#			hsh[foo] = reverse.map do |e|
#				if e.is_a? Array
#					e.foo
#				elsif e.nil?
#					0x8100
#				else
#					e | 0x8000
#				end
#			end.reverse
#		end
	end
	def foobar hsh
		bar hsh
		each do |e|
			e.foobar hsh
		end
	end
end

require_relative 'core'
h = {}
HPACK.const_get(:HuffmanDecodes).foobar h

puts "uint32_t HuffmanDecodes[#{h.length}] = ["
h.length.times do |i|
	STDERR.puts [i, h[i]].inspect
	print "\t", h[i][0]<<16|h[i][1], ",\n"
end
puts "];"
