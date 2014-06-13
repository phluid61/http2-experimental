require 'benchmark'
require_relative 'hpack/core'

puts RUBY_DESCRIPTION

class Array
	# Like #sample, but duplication is okay.
	def pick n
		n.times.map{ sample }
	end
end

## Select likely candidates

CODES=HPACK.const_get(:HuffmanCodes).each_with_index
def choose &block
	CODES.select(&block).map{|x,i| [i].pack('C') }
end

$quad_soup = %w[0 1 2 ]
$octa_soup = %w[; B C E I O P U X j k z]
$short_soup = choose{|x,byte| x[1] <= 8 }
$long_soup  = choose{|x,byte| x[1] > 8 && byte <= 0xFF }
$total_soup = choose{|x,byte| byte <= 0xFF }

## Build strings

count  = 10
length = 15

$quads = []; $hquads = []
$octas = []; $hoctas = []
$shorts = []; $hshorts = []
$longs  = []; $hlongs  = []
$totals = []; $htotals = []
count.times do
	$quads << (b = $quad_soup.pick(length).join); $hquads << HPACK.huffman_code_for(b)
	$octas << (b = $octa_soup.pick(length).join); $hoctas << HPACK.huffman_code_for(b)
	$shorts << (b = $short_soup.pick(length).join); $hshorts << HPACK.huffman_code_for(b)
	$longs  << (b = $long_soup.pick(length).join); $hlongs << HPACK.huffman_code_for(b)
end
# for the "totals" just permute the whole string
$totals << (b = $total_soup.shuffle.join); $htotals << HPACK.huffman_code_for(b)

## Run benchmarks

iters = 10_000

puts ''
puts 'quads = bytes that encode to 4 bits'
puts 'octas = bytes that encode to 8 bits'
puts 'shorts = bytes that encode to <= 8 bits'
puts 'longs  = bytes that encode to >8 bits'
puts ''
puts "#{count} strings per category"
puts "#{length} bytes per string"
puts "#{iters} iterations"
puts ''

Benchmark.bm(16, 'Encode (us/byte)', 'Decode (us/byte)') do |x|
	a =x.report('Encode quads') { iters.times { $quads.each{|s| HPACK.huffman_code_for s } } }
	a+=x.report('Encode octas') { iters.times { $octas.each{|s| HPACK.huffman_code_for s } } }
	a+=x.report('Encode shorts') { iters.times { $shorts.each{|s| HPACK.huffman_code_for s } } }
	a+=x.report('Encode longs') { iters.times { $longs.each{|s| HPACK.huffman_code_for s } } }

	b =x.report('Decode quads') { iters.times { $hquads.each{|s| HPACK.string_from s } } }
	b+=x.report('Decode octas') { iters.times { $hoctas.each{|s| HPACK.string_from s } } }
	b+=x.report('Decode shorts') { iters.times { $hshorts.each{|s| HPACK.string_from s } } }
	b+=x.report('Decode longs') { iters.times { $hlongs.each{|s| HPACK.string_from s } } }

	[a * 1000000 / (count*length*iters), b * 1000000 / (count*length*iters)]
end

puts ''
puts "Random permutation of all 256 bytes"
puts ''

Benchmark.bm(16, 'Encode (us/byte)', 'Decode (us/byte)') do |x|
	a=x.report('Encode all bytes') { iters.times { $totals.each{|s| HPACK.huffman_code_for s } } }
	b=x.report('Decode all bytes') { iters.times { $htotals.each{|s| HPACK.string_from s } } }
	[a * 1000000 / (256*iters), b * 1000000 / (256*iters)]
end

