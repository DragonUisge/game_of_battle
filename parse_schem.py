import struct, zlib, sys

with open("mods/map/schems/barlaeus_arena.mts", "rb") as f:
    raw = f.read()

offset = 6
sx, sy, sz = struct.unpack_from(">HHH", raw, offset)
offset += 6
print(f"Size: {sx}x{sy}x{sz}")
offset += sy
nc = struct.unpack_from(">H", raw, offset)[0]
offset += 2
names = []
for i in range(nc):
    nl = struct.unpack_from(">H", raw, offset)[0]
    offset += 2
    names.append(raw[offset:offset+nl].decode("latin-1"))
    offset += nl

print(f"Names: {nc}, first 5: {names[:5]}")
print(f"Data at offset {offset}")

try:
    data = zlib.decompress(raw[offset:])
    print(f"Zlib OK: {len(data)} (expected {sx*sy*sz*4})")
except Exception as e:
    print(f"No zlib: {e}")
    data = raw[offset:]

total = sx * sy * sz
if len(data) >= total * 2:
    ids = list(struct.unpack_from(f">{total}H", data, 0))
    AIR = names.index("air") if "air" in names else -1
    IGN = names.index("ignore") if "ignore" in names else -1
    print(f"Air={AIR} Ignore={IGN}")
    print(f"\nTop-down y=1:")
    print("Z\\X  " + "".join(f"{x%10}" for x in range(sx)))
    for z in range(sz):
        row = "".join("#" if ids[z*sy*sx + 1*sx + x] not in (AIR, IGN) else "." for x in range(sx))
        print(f"{z:3d}  {row}")
else:
    print(f"Too small: have {len(data)}, need {total*2}")
