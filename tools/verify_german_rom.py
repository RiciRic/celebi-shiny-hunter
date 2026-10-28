"""Offline provenance check; Python is development tooling, never the hunter runtime.

Use only with your own ROM. Reads bytes, prints addresses; never modifies the ROM.
Patterns encode instructions in pret/pokecrystal engine/battle/core.asm.
This is deliberately NOT an automatic profile generator for unknown ROM hacks.
"""
import argparse
import hashlib
import re
import zlib
from pathlib import Path


def verify(path: Path) -> dict:
    rom = path.read_bytes()
    sha1 = hashlib.sha1(rom).hexdigest()
    assert sha1 == "accb584293ba056152f1fd908439b019017ff2fe", "Not the audited German ROM"
    assert len(rom) == 2097152
    addresses = {}

    def match(name, pattern):
        matches = list(re.finditer(pattern, rom, re.DOTALL))
        assert len(matches) == 1, f"{name}: expected one match, got {len(matches)}"
        result = matches[0]
        print(f"{name}: ROM file offset 0x{result.start():06X}")
        return result

    def word(value):
        return int.from_bytes(value, "little")

    # Two calls to the same BattleRandom routine, then UpdateDVs writes B/C.
    m = match("LoadEnemyMon.GenerateDVs", rb"\xcd(..)\x47\xcd\1\x4f\x21(..)\x78\x22\x71\xfa(..)\x3d\x20.")
    addresses["dv1"] = word(m[2]); addresses["dv2"] = word(m[2]) + 1
    addresses["mode"] = word(m[3])
    m = match("DoBattle", rb"\xaf\xea(..)\xea(..)\xea(..)\xea(..)\x3c\xea(..)\x21(..)\x01(..)\x16")
    addresses["ended"] = word(m[4]); addresses["started"] = word(m[5])
    m = match("LoadEnemyMon", rb"\xaf\x21(..)\x01(..)\xcd..\xfa(..)\xa7\xc2..\xfa..\xcb.\xc2..\xfa(..)\xea(..)\xea(..)\xea(..)")
    addresses["species"] = word(m[1]); assert m[1] == m[5]
    addresses["link"] = word(m[3]); addresses["temporary_species"] = word(m[4])
    m = match("LoadEnemyMon.Happiness", rb"\x3e\x46\xea(..)\xfa(..)\xea(..)\x11(..)\x06\x00\x21")
    addresses["level"] = word(m[3]); addresses["max_hp_hi"] = word(m[4])
    m = match("LoadEnemyMon.UpdateStatus", rb"\x21(..)\x22\xaf\x22\xfa(..)\x22\xfa(..)\x77\xfa(..)\xfe\x05")
    addresses["hp_hi"] = word(m[1]) + 2
    assert addresses["max_hp_hi"] == word(m[2])
    addresses["max_hp_lo"] = word(m[3]); addresses["battle_type"] = word(m[4])
    addresses["hp_lo"] = addresses["hp_hi"] + 1
    wild = match("InitEnemyWildmon", rb"\x3e\x01\xea(..)\x3e.\x21..\xcf\xcd..\x21(..)\x11(..)\x01\x04\x00")
    assert word(wild[1]) == addresses["mode"]
    target = ((wild.start() % 0x4000) + 0x4000).to_bytes(2, "little")
    m = match("InitEnemy dispatch", rb"\xfa(..)\xa7\xc2..\xc3" + re.escape(target))
    addresses["trainer"] = word(m[1])
    expected = {
        "link": 0xC2DC, "ended": 0xC734, "temporary_species": 0xD204,
        "species": 0xD206, "dv1": 0xD20C, "dv2": 0xD20D, "level": 0xD213,
        "hp_hi": 0xD216, "hp_lo": 0xD217, "max_hp_hi": 0xD218, "max_hp_lo": 0xD219,
        "mode": 0xD22D, "trainer": 0xD22F, "battle_type": 0xD230, "started": 0xD264,
    }
    assert addresses == expected, f"Address mismatch: {addresses}"
    print(f"SHA1={sha1} CRC32={zlib.crc32(rom):08x}")
    for name, address in addresses.items():
        print(f"{name:20} 0x{address:04X}")
    print("All 15 profile fields match the German ROM's machine instructions.")
    return addresses


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    verify(parser.parse_args().rom)
