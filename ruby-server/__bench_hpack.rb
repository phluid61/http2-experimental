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

Benchmark.bm(13) do |x|
	x.report('Encode quads') { iters.times { $quads.map{|s| HPACK.huffman_code_for s } } }
	x.report('Encode octas') { iters.times { $octas.map{|s| HPACK.huffman_code_for s } } }
	x.report('Encode shorts') { iters.times { $shorts.map{|s| HPACK.huffman_code_for s } } }
	x.report('Encode longs') { iters.times { $longs.map{|s| HPACK.huffman_code_for s } } }

	x.report('Decode quads') { iters.times { $hquads.map{|s| HPACK.string_from s } } }
	x.report('Decode octas') { iters.times { $hoctas.map{|s| HPACK.string_from s } } }
	x.report('Decode shorts') { iters.times { $hshorts.map{|s| HPACK.string_from s } } }
	x.report('Decode longs') { iters.times { $hlongs.map{|s| HPACK.string_from s } } }
end

puts ''
puts "Random permutation of all 256 bytes"
puts ''

Benchmark.bm(16) do |x|
	x.report('Encode all bytes') { iters.times { $totals.map{|s| HPACK.huffman_code_for s } } }
	x.report('Decode all bytes') { iters.times { $htotals.map{|s| HPACK.string_from s } } }
end
