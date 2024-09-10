module vpng

import os
import compress.zlib
import hash.crc32
import encoding.binary

fn write_(png PngFile, filename string) {
	file_bytes := write2_(png)
	os.write_file(filename, file_bytes.bytestr()) or { println('Error writing file ${err}') }
}

fn write2_(png PngFile) []u8 {
	mut file_bytes := []u8{}
	signature(mut file_bytes)
	write_chunks(mut file_bytes, png)
	return file_bytes
}

fn signature(mut file_bytes []u8) {
	file_bytes << png_signature
}

fn ihdr_chunk(mut file_bytes []u8, png PngFile) {
	mut ihdr_bytes := [u8(`I`), `H`, `D`, `R`]
	ihdr_bytes << binary.big_endian_get_u32(png.width) // WIDTH
	ihdr_bytes << binary.big_endian_get_u32(png.height) // HEIGHT
	ihdr_bytes << png.ihdr.bit_depth // BIT DEPTH
	ihdr_bytes << png.ihdr.color_type // COLOR TYPE
	ihdr_bytes << png.ihdr.compression_method // Compression Method
	ihdr_bytes << png.ihdr.filter_method // Filter Method
	ihdr_bytes << png.ihdr.interlace_method // Interlace Method
	len_bytes := binary.big_endian_get_u32(u32(ihdr_bytes.len) - 4)
	crc_bytes := binary.big_endian_get_u32(crc32.sum(ihdr_bytes))
	file_bytes << len_bytes
	file_bytes << ihdr_bytes
	file_bytes << crc_bytes
}

fn iend_chunk(mut file_bytes []u8) {
	iend_bytes := [u8(`I`), `E`, `N`, `D`]
	file_bytes << binary.big_endian_get_u32(0)
	file_bytes << iend_bytes
	file_bytes << binary.big_endian_get_u32(crc32.sum(iend_bytes))
}

fn idat_chunk(mut file_bytes []u8, png PngFile) {
	mut idat_bytes := []u8{}
	for y in 0 .. png.height {
		idat_bytes << 0
		for x in 0 .. png.width {
			pix := png.pixels[y * png.width + x]
			match pix {
				TrueColor {
					idat_bytes << pix.red
					idat_bytes << pix.green
					idat_bytes << pix.blue
				}
				TrueColorAlpha {
					idat_bytes << pix.red
					idat_bytes << pix.green
					idat_bytes << pix.blue
					idat_bytes << pix.alpha
				}
				Indexed {
					idat_bytes << pix.index
				}
				else {}
			}
		}
	}

	out := zlib.compress(idat_bytes) or { panic('failed to compress IDAT chunks') }
	mut out_bytes := [u8(`I`), `D`, `A`, `T`]
	out_bytes << out
	file_bytes << binary.big_endian_get_u32(u32(out_bytes.len) - 4)
	file_bytes << out_bytes
	file_bytes << binary.big_endian_get_u32(crc32.sum(out_bytes))
}

fn plte_chunk(mut file_bytes []u8, png PngFile) {
	if png.pixel_type != PixelType.indexed {
		return
	}
	mut out_bytes := [u8(`P`), `L`, `T`, `E`]
	for i in 0 .. png.palette.len {
		out_bytes << [png.palette[i].red]
		out_bytes << [png.palette[i].green]
		out_bytes << [png.palette[i].blue]
	}
	file_bytes << binary.big_endian_get_u32(u32(out_bytes.len) - 4)
	file_bytes << out_bytes
	file_bytes << binary.big_endian_get_u32(crc32.sum(out_bytes))
}

fn write_chunks(mut file_bytes []u8, png PngFile) {
	ihdr_chunk(mut file_bytes, png)
	plte_chunk(mut file_bytes, png)
	idat_chunk(mut file_bytes, png)
	iend_chunk(mut file_bytes)
}
