local M = {}
local function byte(n)
    assert(type(n)=="number" and n==math.floor(n) and n>=0 and n<=255, "Invalid RAM byte")
    return n
end
function M.dvs(first, second)
    byte(first); byte(second)
    local a, d, s, c = math.floor(first/16), first%16, math.floor(second/16), second%16
    return { attack=a, defense=d, speed=s, special=c,
        shiny=d==10 and s==10 and c==10 and math.floor(a/2)%2==1,
        key=string.format("%02X%02X", first, second) }
end
function M.read(read, addresses)
    local result = {}
    for name, address in pairs(addresses) do
        assert(type(address)=="number" and address==math.floor(address)
            and address>=0xC000 and address<0xE000, "Invalid WRAM address: "..name)
        result[name] = byte(read(address))
    end
    result.hp = result.hp_hi*256 + result.hp_lo
    result.max_hp = result.max_hp_hi*256 + result.max_hp_lo
    return result
end
function M.overworld(s)
    assert(s.mode==0 and s.started==0 and s.link==0,
        "Savestate must be in overworld, before the event, with started=0 and link=0")
end
function M.validate(s)
    assert(s.mode==1 and s.started==1, "Battle initialization not proven")
    assert(s.link==0 and s.trainer==0 and s.ended==0, "Not an active local wild battle")
    assert(s.battle_type==11, "Not the natural Celebi shrine battle (type 11)")
    assert(s.species==251 and s.temporary_species==251, "Wild opponent is not Celebi (251)")
    assert(s.level==30, "Unexpected Celebi level")
    assert(s.max_hp>=100 and s.max_hp<=109 and s.hp==s.max_hp, "Invalid initial Celebi HP")
    local dv = M.dvs(s.dv1, s.dv2)
    -- Fresh level-30 Celebi, base HP 100, zero stat experience.
    local hp_dv = (dv.attack%2)*8 + (dv.defense%2)*4 + (dv.speed%2)*2 + dv.special%2
    assert(s.max_hp==math.floor((100+hp_dv)*2*30/100)+40, "HP/DVs inconsistent")
    return dv
end
function M.fingerprint(s)
    return table.concat({s.species,s.temporary_species,s.level,s.dv1,s.dv2,s.hp,s.max_hp}, ":")
end
return M
