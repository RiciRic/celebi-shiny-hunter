local source=debug.getinfo(1,"S").source:gsub("^@",""):gsub("\\","/")
local root=source:match("^(.*)/tests/[^/]+$") or "."
package.path=root.."/lua/?.lua;"..package.path
local Detector=require("detector")
local Controller=require("controller")
local RNG=require("rng")
local Profiles=require("profiles")
local Storage=require("storage")
local Settings=require("settings")
local count=0
local function test(name, fn)
    local ok,err=pcall(fn)
    if not ok then error("FAIL "..name..": "..tostring(err)) end
    count=count+1; print("PASS "..name)
end
local function rejects(fn) assert(not pcall(fn),"Expected rejection") end
local function config()
    local c=dofile(root.."/lua/config.lua"); c.mode="hunt"; c.timeout_frames=60
    c.rng.delay_count=3; c.rng.delay_stride=1
    return c
end
local function encounter(a,b)
    local d=Detector.dvs(a,b)
    local hp=math.floor((100+(d.attack%2)*8+(d.defense%2)*4+(d.speed%2)*2+d.special%2)*0.6)+40
    return { mode=1,started=1,link=0,trainer=0,ended=0,battle_type=11,
        species=251,temporary_species=251,level=30,dv1=a,dv2=b,hp=hp,max_hp=hp }
end
local function baseline()
    local s=encounter(0x2A,0xAA) -- intentionally stale shiny data!
    s.mode=0; s.started=0; return s
end
local function mock(c)
    c=c or config()
    local env={ loads=0,saves=0,keys_value=0,s=baseline(),reports=0 }
    local adapter={
        time=function() return 0 end,
        sample=function() return env.s end,
        load=function() env.loads=env.loads+1; env.s=baseline(); return true end,
        keys=function(k) env.keys_value=k end,
        capture=function() return "shiny state bytes" end,
        save=function(data) env.saves=env.saves+1; env.saved=data; return "shiny.state" end,
        report=function() env.reports=env.reports+1 end,
    }
    local h=Controller.new(c,adapter)
    h:start()
    local function ready()
        if h.status=="NEXT" then h:tick() end
        for _=1,100 do if h.status~="DELAY" then break end; h:tick() end
        assert(h.status=="TRIGGER",h.reason)
    end
    local function feed(a,b)
        ready()
        env.s=encounter(a,b); env.s.started=0; h:tick()
        env.s.started=1
        for _=1,c.stable_frames do h:tick() end
        assert(env.keys_value==0,"Inputs continued after initialization")
    end
    return h,env,adapter,feed,ready
end
test("exhaustive 65,536 DV combinations: exactly eight shinies",function()
    local shinies=0
    for a=0,255 do for b=0,255 do
        local d=Detector.dvs(a,b)
        assert(d.attack*16+d.defense==a and d.speed*16+d.special==b)
        local attack=d.attack
        local accepted=attack==2 or attack==3 or attack==6 or attack==7 or attack==10 or attack==11 or attack==14 or attack==15
        assert(d.shiny==(accepted and d.defense==10 and d.speed==10 and d.special==10))
        if d.shiny then shinies=shinies+1 end
    end end
    assert(shinies==8)
end)
test("DV boundary examples and invalid bytes",function()
    assert(Detector.dvs(0x2A,0xAA).shiny and Detector.dvs(0xFA,0xAA).shiny)
    for _,pair in ipairs({{0x1A,0xAA},{0x4A,0xAA},{0xEA,0xA9},{0xE9,0xAA},{0xEA,0x9A},{0,0},{255,255}}) do
        assert(not Detector.dvs(pair[1],pair[2]).shiny)
    end
    rejects(function() Detector.dvs(-1,0) end)
    rejects(function() Detector.dvs(256,0) end)
    rejects(function() Detector.dvs(nil,0) end)
    rejects(function() Detector.dvs(1.5,0) end)
end)
test("species, natural battle, level and HP consistency",function()
    assert(Detector.validate(encounter(0xEA,0xAA)).shiny)
    for key,value in pairs({species=250,temporary_species=1,level=29,hp=0,max_hp=120,
        mode=2,started=0,link=1,trainer=1,ended=1,battle_type=7}) do
        local s=encounter(0xEA,0xAA); s[key]=value
        rejects(function() Detector.validate(s) end)
    end
end)
test("invalid RAM addresses and unreadable bytes fail closed",function()
    for _,address in ipairs({0,0xBFFF,0xE000,0xD20C+0.5}) do
        rejects(function() Detector.read(function() return 0 end,{dv1=address}) end)
    end
    rejects(function() Detector.read(function() return nil end,{dv1=0xD20C}) end)
    rejects(function() Detector.read(function() return 300 end,{dv1=0xD20C}) end)
end)
test("ROM identity allowlist and explicit mismatch",function()
    assert(Profiles.select("616d85de",2097152,"auto").id=="crystal-de")
    assert(Profiles.select("ee6f5188",2097152,"crystal-en-10"))
    assert(Profiles.select("3358e30a",2097152,"auto"))
    rejects(function() Profiles.select("deadbeef",2097152,"auto") end)
    rejects(function() Profiles.select("616d85de",1,"auto") end)
    rejects(function() Profiles.select("616d85de",2097152,"crystal-en-11") end)
end)
test("bank-independent WRAM reads use offsets, never Dxxx bus",function()
    local p=Profiles.list["616d85de"]
    local memory={}; for _,a in pairs(p.addresses) do memory[a-0xC000]=0 end
    C={PLATFORM={GB=1}}
    emu={ platform=function() return 1 end, checksum=function() return string.char(0x61,0x6d,0x85,0xde) end,
        romSize=function() return 2097152 end, read8=function() error("Bus read forbidden") end,
        memory={wram={size=function() return 0x8000 end,read8=function(_,offset) return assert(memory[offset]) end}} }
    memory[0x1206]=251; memory[0x120C]=0xEA
    local _,sample=require("adapter").connect("auto")
    local s=sample(); assert(s.species==251 and s.dv1==0xEA)
    emu=nil; C=nil
end)
test("stale shiny in overworld cannot count as an encounter",function()
    local h,e=mock()
    for _=1,10 do h:tick() end
    assert(h.encounters==0 and e.saves==0 and e.loads==1)
end)
test("battle mode alone cannot authorize reset; missing initialization times out",function()
    local h,e,_,_,ready=mock(); ready()
    e.s.mode=1; e.s.started=0
    for _=1,70 do h:tick() end
    assert(h.status=="ERROR" and h.timeouts==1 and h.encounters==0 and e.loads==1 and e.keys_value==0)
end)
test("baseline already in battle is refused",function()
    local h,e,adapter=mock()
    adapter.load=function() e.loads=e.loads+1; e.s=encounter(1,2); return true end
    h=Controller.new(config(),adapter); h:start()
    assert(h.status=="ERROR" and e.loads==2 and e.saves==0)
end)
test("new encounter may legitimately repeat previous DVs",function()
    local h,e,_,feed=mock()
    feed(0x12,0x34); assert(h.status=="NEXT" and h.encounters==1 and e.loads==1)
    feed(0x12,0x34); assert(h.encounters==2 and h.rng.unique==1 and e.loads==2)
end)
test("two stable initialized frames are required",function()
    local h,e,_,_,ready=mock(); ready()
    e.s=encounter(0x12,0x34); h:tick(); assert(h.encounters==0)
    e.s=encounter(0x56,0x78); h:tick(); assert(h.encounters==0)
    h:tick(); assert(h.encounters==1)
end)
test("unknown enemy halts with no reset",function()
    local h,e,_,_,ready=mock(); ready()
    e.s=encounter(1,2); e.s.species=25; h:tick()
    assert(h.status=="ERROR" and h.errors==1 and e.loads==1 and e.keys_value==0)
    for _=1,10 do h:tick() end; assert(e.loads==1)
end)
test("trainer battle, invalid mode, link and disappearing battle stop",function()
    for _,change in ipairs({{mode=2},{mode=255},{link=1},{battle_type=7},{trainer=1}}) do
        local h,e,_,_,ready=mock(); ready(); e.s=encounter(1,2)
        for k,v in pairs(change) do e.s[k]=v end
        h:tick(); assert(h.status=="ERROR" and e.loads==1)
    end
    local h,e,_,_,ready=mock(); ready(); e.s=encounter(1,2); e.s.started=0; h:tick()
    e.s=baseline(); h:tick(); assert(h.status=="ERROR")
end)
test("shiny latches before saving and never resets afterwards",function()
    local h,e,adapter,feed=mock()
    adapter.save=function(data) assert(h.status=="SHINY"); e.saves=e.saves+1; return "found.state" end
    feed(0xEA,0xAA)
    assert(h.status=="SHINY" and e.saves==1 and h.shiny_buffer=="shiny state bytes" and e.keys_value==0)
    for _=1,100 do h:tick() end
    assert(e.loads==1 and e.saves==1)
end)
test("failed shiny publication retains memory and never resets",function()
    local h,e,adapter,feed=mock(); adapter.save=function() error("disk full") end
    feed(0x2A,0xAA)
    assert(h.status=="ERROR" and h.shiny_buffer=="shiny state bytes" and h.last.shiny)
    for _=1,100 do h:tick() end; assert(e.loads==1)
end)
test("failed state capture and load stop",function()
    local h,e,adapter,feed=mock(); adapter.capture=function() return nil end
    feed(0x2A,0xAA); assert(h.status=="ERROR" and e.loads==1 and e.saves==0)
    adapter.load=function() return false end
    local other=Controller.new(config(),adapter); other:start(); assert(other.status=="ERROR")
end)
test("optional screenshot failure does not lose the saved shiny",function()
    local h,e,adapter,feed=mock(); adapter.screenshot=function() error("no screenshot") end
    feed(0xEA,0xAA); assert(h.status=="SHINY" and e.saves==1 and h.reason:find("screenshot failed"))
end)
test("RNG identical streak stops without discarding current encounter",function()
    local h,e,_,feed=mock()
    for _=1,8 do feed(0x12,0x34) end
    assert(h.status=="ERROR" and h.encounters==8 and e.loads==8)
end)
test("RNG window detects low diversity without a streak",function()
    local r=RNG.new({window=8,minimum_unique=3,identical_limit=8})
    for i=1,7 do assert(r:add(tostring(i%2))) end
    assert(not r:add("0"))
end)
test("all 32,896 RNG schedules are distinct and exhaustion stops",function()
    local c=dofile(root.."/lua/config.lua"); local seen={}
    local total=c.rng.delay_count*c.rng.gap_variants*c.rng.hold_variants
    assert(total==32896)
    for i=1,total do
        local p=RNG.plan(i,c.rng,c.controls.base_gap)
        local key=p.delay..":"..p.gap..":"..p.hold
        assert(not seen[key]); seen[key]=true
    end
    rejects(function() RNG.plan(total+1,c.rng,c.controls.base_gap) end)
end)
test("validation mode observes diversity then stops",function()
    local c=config(); c.mode="validate"; c.validation_encounters=3
    local h,e,_,feed=mock(c)
    feed(0x12,0x34); feed(0x56,0x78); feed(0x91,0x23)
    assert(h.status=="VALIDATED" and h.rng.unique==3 and e.loads==3)
    h:tick(); assert(e.loads==3)
end)
test("configuration rejects broken timing and RNG parameters",function()
    Settings.validate(config())
    local c=config(); c.rng.delay_stride=3; rejects(function() Settings.validate(c) end)
    c=config(); c.stable_frames=0; rejects(function() Settings.validate(c) end)
    c=config(); c.controls.base_gap=0; rejects(function() Settings.validate(c) end)
    c=config(); c.speed=10; rejects(function() Settings.validate(c) end)
end)
test("blocking battle intro still gets A; initialized battle never does",function()
    local h,e,_,_,ready=mock(); ready(); e.s=encounter(1,2); e.s.started=0
    local presses=0
    for _=1,20 do h:tick(); if e.keys_value==1 then presses=presses+1 end end
    assert(presses>0 and h.encounters==0)
    e.s.started=1; h:tick(); assert(e.keys_value==0)
    h:tick(); assert(h.encounters==1)
end)
test("entrypoint integration: reload, callbacks, SRAM flags, frame guard, cleanup",function()
    local original_dofile=dofile
    local c=config(); c.mode="validate"; c.validation_encounters=2; c.log=false
    local temp=os.tmpname(); c.state=temp; c.shiny=temp..".shiny.state"
    local f=assert(io.open(temp,"wb")); f:write("baseline"); f:close()
    local handlers,serial={},0
    callbacks={add=function(_,name,fn) serial=serial+1; handlers[serial]={name=name,fn=fn}; return serial end,
        remove=function(_,id) handlers[id]=nil end}
    console={createBuffer=function() return {clear=function() end,print=function() end} end,
        log=function() end,error=function(_,msg) error(msg) end}
    C={PLATFORM={GB=1}}
    local frame,loads,keys=42,0,0
    local sample=baseline()
    local function raw(address)
        local p=Profiles.list["616d85de"].addresses
        local values={hp_hi=math.floor(sample.hp/256),hp_lo=sample.hp%256,
            max_hp_hi=math.floor(sample.max_hp/256),max_hp_lo=sample.max_hp%256}
        for name,a in pairs(p) do if a==address then return values[name] or sample[name] end end
        error("Unexpected RAM read")
    end
    emu={platform=function() return 1 end,checksum=function() return string.char(0x61,0x6d,0x85,0xde) end,
        romSize=function() return 2097152 end,currentFrame=function() return frame end,
        setKeys=function(_,k) keys=k end,
        loadStateBuffer=function(_,data,flags)
            assert(data=="baseline" and flags==9,"Must mask SRAM, not write it back")
            loads=loads+1; frame=42; sample=baseline(); return true
        end,
        memory={wram={size=function() return 32768 end,read8=function(_,a) return raw(a+0xC000) end}} }
    dofile=function(path) if path:match("/lua/config.lua$") then return c end; return original_dofile(path) end
    original_dofile(root.."/hunter.lua")
    dofile=original_dofile
    local function advance()
        for _,handler in pairs(handlers) do if handler.name=="frame" then handler.fn(); break end end
        frame=frame+1
    end
    for attempt=1,2 do
        for _=1,10 do if CELEBI_HUNTER.status=="TRIGGER" then break end; advance() end
        assert(CELEBI_HUNTER.status=="TRIGGER",CELEBI_HUNTER.reason)
        sample=encounter(0x12+attempt,0x34); sample.started=0; advance()
        sample.started=1; advance(); advance()
    end
    assert(CELEBI_HUNTER.status=="VALIDATED" and loads==2 and keys==0)
    assert(next(handlers)==nil,"Terminal callbacks leaked")
    -- Repeat to exercise shutdown of the previous controller and detect external jumps.
    dofile=function(path) if path:match("/lua/config.lua$") then return c end; return original_dofile(path) end
    original_dofile(root.."/hunter.lua"); dofile=original_dofile
    advance(); frame=frame+10
    console.error=function() end
    advance()
    assert(CELEBI_HUNTER.status=="ERROR" and keys==0 and next(handlers)==nil)
    assert(CELEBI_HUNTER.reason:find("frame jump"))
    CELEBI_HUNTER=nil; CELEBI_STOP=nil; CELEBI_RETRY_SAVE=nil
    emu=nil; C=nil; callbacks=nil; console=nil; os.remove(temp)
end)
test("Windows state publication preserves existing file bytes",function()
    local temp=os.tmpname(); os.remove(temp)
    local path=temp..".state"
    assert(not Storage.exists(path))
    Storage.save(path,"first shiny\0binary")
    rejects(function() Storage.save(path,"second shiny") end)
    local f=assert(io.open(path,"rb")); assert(f:read("*a")=="first shiny\0binary"); f:close()
    assert(os.remove(path))
end)
test("state write/publication errors do not create final output",function()
    local temp=os.tmpname(); os.remove(temp)
    local path=temp.."/missing/shiny.state"
    rejects(function() Storage.save(path,"state") end)
    rejects(function() Storage.save(path,"") end)
end)
test("concurrent destination creation cannot overwrite a shiny",function()
    local temp=os.tmpname(); os.remove(temp)
    local path=temp..".state"
    local rename=os.rename
    local staging
    os.rename=function(from,to)
        if to==path and from~=to then
            staging=from
            local f=assert(io.open(path,"wb")); f:write("other shiny"); f:close()
        end
        return rename(from,to)
    end
    local ok=pcall(function() Storage.save(path,"new shiny") end)
    os.rename=rename
    assert(not ok)
    local f=assert(io.open(path,"rb")); assert(f:read("*a")=="other shiny"); f:close()
    os.remove(path); if staging then os.remove(staging) end
end)
print(string.format("\n%d tests passed",count))
