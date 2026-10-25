"""Packs the icon PNGs (made by the game icon script) into one Windows .ico file.
Usage: python make_ico.py <folder with icon_<size>.png> <out.ico>"""
import struct, sys, os
folder, out = sys.argv[1], sys.argv[2]
sizes = [16, 24, 32, 48, 64, 128, 256]
images = [open(os.path.join(folder, "icon_%d.png" % s), "rb").read() for s in sizes]
data = struct.pack("<HHH", 0, 1, len(sizes))
offset = 6 + 16 * len(sizes)
for s, png in zip(sizes, images):
    data += struct.pack("<BBBBHHII", s % 256, s % 256, 0, 0, 1, 32, len(png), offset)
    offset += len(png)
open(out, "wb").write(data + b"".join(images))
print("wrote", out)
