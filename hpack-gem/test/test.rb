require './hpack'

def q *strs
	strs.each do |str|
		if str.empty?
			puts ' '*40 + '| 0'
		else
			puts str.to_s.each_byte.map{|b|'%02x'%b}.each_slice(2).map{|s|s.join}.each_slice(8).map{|s|s.join(' ').ljust(40)+'|'}.join("\n") + " #{str.bytesize}"
		end
	end
end

$strings = [
	'',
	'www.example.com',
	'/sample/path',
	'set-cookie',
	'text/html,text/*;q=0.8,*/*;q=0.2',
]

$strings.each do |s|
	huff, enc = HPACK.huffman_encode(s), HPACK.encode(s)
	p s
	puts '## huffman_encode:'; q huff
	puts '## encode:'; q enc

	_ = HPACK.huffman_decode(huff)
	unless _ == s
		puts '## huffman_decode:'; q _
	end

	_ = HPACK.decode(enc)
	unless _ == s
		puts '## decode:'; q _
	end

	puts '-'*5
end

