
#include <stddef.h>
#include <stdint.h>

uint32_t HuffmanDecodes[] = {
	65538,
	196612,
	983056,
	327686,
	524297,
	2150662193,
	2150760455,
	2149613615,
	655371,
	786445,
	2150858849,
	2154004581,
	2154397807,
	2155085838,
	2149941294,
	1114130,
	2031648,
	1245204,
	1638426,
	1376278,
	1507352,
	2150924341,
	2151055415,
	2151186489,
	2151317565,
	1769500,
	1900574,
	2153021540,
	2154266728,
	2154594413,
	2154725488,
	2162722,
	2949166,
	2293796,
	2555944,
	2154987635,
	2424870,
	2150006828,
	2150465601,
	2687018,
	2818092,
	2151972934,
	2152169549,
	2152628307,
	2153742434,
	3080240,
	3604536,
	3211314,
	3342388,
	2154201205,
	2155249783,
	2155380857,
	3473462,
	2151383106,
	2151907397,
	3735610,
	4128832,
	3866684,
	3997758,
	2152300623,
	2152759381,
	2153283690,
	2154528890,
	4259906,
	4653128,
	4390980,
	4522054,
	2149744681,
	2152235082,
	2152431692,
	2152824914,
	4784202,
	4915276,
	2153152599,
	2153349210,
	2154889293,
	5111887,
	2150137898,
	2150334527,
	5242961,
	2153480285,
	5374035,
	2155643006,
	5505109,
	2149679143,
	5636183,
	2149810270,
	5767257,
	2149875774,
	2151678042,
	5963868,
	2151448699,
	2155675741,
	2153775198,
	6226016,
	6357090,
	10420384,
	6488164,
	8454274,
	6619238,
	7536756,
	6750312,
	7143534,
	6881386,
	7012460,
	2158264485,
	2158395559,
	2158526633,
	2158657707,
	7274608,
	7405682,
	2158788781,
	2158919855,
	2159050929,
	2159182003,
	7667830,
	8061052,
	7798904,
	7929978,
	2159313077,
	2159444151,
	2159575225,
	2159706299,
	8192126,
	8323200,
	2159837373,
	2159968447,
	2160099521,
	2160230595,
	8585348,
	9502866,
	8716422,
	9109644,
	8847496,
	8978570,
	2160361669,
	2160492743,
	2160623817,
	2160754891,
	9240718,
	9371792,
	2160885965,
	2161017039,
	2161148113,
	2161279187,
	9633940,
	10027162,
	9765014,
	9896088,
	2161410261,
	2161541335,
	2161672409,
	2161803483,
	10158236,
	10289310,
	2161934557,
	2162065631,
	2162196705,
	2162327779,
	10551458,
	12714179,
	10682532,
	11600050,
	10813606,
	11206828,
	10944680,
	11075754,
	2162458853,
	2162589927,
	2162721001,
	2162852075,
	11337902,
	11468976,
	2162983149,
	2163114223,
	2163245297,
	2163376371,
	11731124,
	12124346,
	11862198,
	11993272,
	2163507445,
	2163638519,
	2163769593,
	2163900667,
	12255420,
	12386494,
	2164031741,
	2164162815,
	2164261055,
	12583105,
	2147516417,
	2147647491,
	2147778565,
	12845253,
	14811363,
	12976327,
	13893845,
	13107401,
	13500623,
	13238475,
	13369549,
	2147909639,
	2148040713,
	2148171787,
	2148302861,
	13631697,
	13762771,
	2148433935,
	2148565009,
	2148696083,
	2148827157,
	14024919,
	14418141,
	14155993,
	14287067,
	2148958231,
	2149089305,
	2149220379,
	2149351453,
	14549215,
	14680289,
	2149482527,
	2153545855,
	2155905153,
	2156036227,
	14942437,
	15859955,
	15073511,
	15466733,
	15204585,
	15335659,
	2156167301,
	2156298375,
	2156429449,
	2156560523,
	15597807,
	15728881,
	2156691597,
	2156822671,
	2156953745,
	2157084819,
	15991029,
	16384251,
	16122103,
	16253177,
	2157215893,
	2157346967,
	2157478041,
	2157609115,
	16515325,
	16646399,
	2157740189,
	2157871263,
	2158002337,
	2158133411
};

#define ZERO(tc) (uint16_t)((tc)>>16)
#define ONE(tc) (uint16_t)((tc)&0xFFFF)

#define IS_INT(x) (((x)&0x8000)==0x8000)
#define VALUE_OF(x) ((x)&0x7FFF)

int huffman_decoder_error;
#define ERROR_OVERFLOW  1
#define ERROR_TRUNCATED 2
#define ERROR_EOS       3

size_t huffman_decode(uint8_t *huff, size_t bytesize, uint8_t *buff, size_t n) {
	size_t count = 0;
	uint32_t tc = *HuffmanDecodes;
	uint16_t tmp;
	uint8_t byte, bc, mask;

	huffman_decoder_error = 0;

	if (bytesize < 1) {
		return 0;
	}

	if (n < 1) {
		huffman_decoder_error = ERROR_OVERFLOW;
		return 0;
	}

	while (bytesize > 0) {
		byte = *huff; huff++; bytesize--;
		bc = 0x80;   /* bit cursor */
		mask = 0x7F; /* padding mask */
		while (bc > 0) {
			if ((byte & bc) == bc) {
				tmp = ONE(tc);
			} else {
				tmp = ZERO(tc);
			}
			if (IS_INT(tmp)) {
				tmp = VALUE_OF(tmp);
				if (tmp > 0xFF) {
					huffman_decoder_error = ERROR_EOS;
					return 0;
				} else {
					*buff = (uint8_t)(tmp); buff++; count++; n--;
					if (bytesize < 1 && (byte & mask) == mask) {
						tc = 0;
						goto done;
					} else if (n < 1) {
						huffman_decoder_error = ERROR_OVERFLOW;
						return count;
					} else {
						tc = *HuffmanDecodes;
					}
				}
			} else {
				/*tmp = VALUE_OF(tmp);*/
				/* FIXME: assert(tmp < 256) */
				tc = HuffmanDecodes[tmp];
			}
			bc >>= 1;
			mask >>= 1;
		}
	}
done:
	if (tc) {
		huffman_decoder_error = ERROR_TRUNCATED;
		/*return count;*/
	}
	return count;
}
