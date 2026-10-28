-- Source provenance and German binary verification: docs/RESEARCH.md.
local M = {}
local addresses = {
    link = 0xC2DC, ended = 0xC734, temporary_species = 0xD204,
    species = 0xD206, dv1 = 0xD20C, dv2 = 0xD20D,
    level = 0xD213, hp_hi = 0xD216, hp_lo = 0xD217,
    max_hp_hi = 0xD218, max_hp_lo = 0xD219,
    mode = 0xD22D, trainer = 0xD22F, battle_type = 0xD230,
    started = 0xD264,
}
M.list = {
    ["616d85de"] = { id="crystal-de", name="Kristall (Germany)", addresses=addresses,
        sha1="accb584293ba056152f1fd908439b019017ff2fe" },
    ["ee6f5188"] = { id="crystal-en-10", name="Crystal (USA) 1.0", addresses=addresses,
        sha1="f4cd194bdee0d04ca4eac29e09b8e4e9d818c133" },
    ["3358e30a"] = { id="crystal-en-11", name="Crystal (USA, Europe) 1.1", addresses=addresses,
        sha1="f2f52230b536214ef7c9924f483392993e226cfb" },
}
function M.select(crc, size, requested)
    local p = M.list[crc]
    assert(size == 2097152 and p, "Unknown ROM CRC32/size: " .. tostring(crc))
    assert(requested == "auto" or requested == p.id, "Configured ROM does not match loaded ROM")
    return p
end
return M
