require 'mkmf'

$MYLIBDIR = Dir.pwd+'/mk-hpack'
$MYLIBNAME = %(hpack)

INCLUDE_DIR = RbConfig::CONFIG['includedir']
LIBDIR      = RbConfig::CONFIG['libdir']

dir_config('hpack', [INCLUDE_DIR], [LIBDIR, $MYLIBDIR])

unless find_header('hpack.h', $MYLIBDIR)
	abort 'mk-hpack is missing (1)'
end

unless find_library($MYLIBNAME, 'huffman_encode')
	abort 'mk-hpack is missing (2)'
end

create_makefile('hpack')

