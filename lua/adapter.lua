local Detector = require("detector")
local Profiles = require("profiles")
local Storage = require("storage")
local M = {}
function M.path(root, path)
    if not path:match("^%a:[/\\]") and not path:match("^[/\\]") then path=root.."/"..path end
    path=path:gsub("\\","/")
    local prefix=path:match("^//") and "//" or (path:match("^/") and "/" or "")
    local parts={}
    for part in path:gmatch("[^/]+") do
        if part==".." then assert(#parts>1,"Path escapes root"); table.remove(parts)
        elseif part~="." then parts[#parts+1]=part end
    end
    return prefix..table.concat(parts,"/")
end
function M.connect(requested)
    assert(emu and emu:platform()==C.PLATFORM.GB, "Load a Game Boy Color ROM in mGBA first")
    local crc=emu:checksum() -- 0.10.5 exposes CRC32 as four big-endian bytes
    assert(type(crc)=="string" and #crc==4, "Unexpected mGBA checksum result")
    crc=crc:gsub(".",function(ch) return string.format("%02x",ch:byte()) end)
    local profile=Profiles.select(crc,emu:romSize(),requested)
    assert(emu.memory and emu.memory.wram and emu.memory.wram:size()>=0x8000, "CGB WRAM domain unavailable")
    local function sample()
        -- Raw domain offsets select bank 1 explicitly; bus reads at D000 can
        -- accidentally sample a temporary graphics bank selected via FF70.
        return Detector.read(function(address) return emu.memory.wram:read8(address-0xC000) end,profile.addresses)
    end
    return profile, sample, crc
end
function M.status(h, profile)
    local elapsed=math.max(0,os.time()-h.started_at)
    local avg=h.encounters>0 and elapsed/h.encounters or 0
    local rate=elapsed>0 and h.encounters*3600/elapsed or 0
    local dv=h.last
    return string.format(
        "%s | %s\nEncounters: %d | Attempts: %d | Unique DVs: %d\n"..
        "Last: %s | Atk/Def/Spd/Spc: %s\nElapsed: %ds | Average: %.2fs | Encounters/hour: %.1f\n"..
        "Errors: %d | Timeouts: %d | Emulated frames: %d\n%s",
        profile.id,h.status,h.encounters,h.attempts,h.rng.unique,
        dv and dv.key or "-",dv and string.format("%d/%d/%d/%d",dv.attack,dv.defense,dv.speed,dv.special) or "-",
        elapsed,avg,rate,h.errors,h.timeouts,h.frames,h.reason or "")
end
function M.create(root, config)
    local profile,sample,crc=M.connect(config.rom)
    local state_path=M.path(root,config.state)
    local shiny_path=M.path(root,config.shiny)
    assert(state_path:lower()~=shiny_path:lower(), "Baseline and shiny paths must differ")
    Storage.preflight(shiny_path)
    local file=assert(io.open(state_path,"rb"),"Baseline savestate missing: "..state_path)
    local baseline=file:read("*a"); file:close()
    assert(baseline and #baseline>0,"Empty baseline state")
    local log
    if config.log then
        local log_path=M.path(root,config.log)
        assert(log_path:lower()~=state_path:lower() and log_path:lower()~=shiny_path:lower(),"Log path aliases a state file")
        log=assert(io.open(log_path,"a"),"Cannot open log")
    end
    local previous_frame, just_loaded
    local panel=console:createBuffer("Celebi Hunter")
    local function display(h) panel:clear(); panel:print(M.status(h,profile)) end
    local function report(h)
        local text=M.status(h,profile)
        if h.last_sample then
            local s=h.last_sample
            text=text..string.format("\nROM=%s CRC32=%s Species=%d TempSpecies=%d Level=%d HP=%d/%d Type=%d Mode=%d Started=%d Delay=%d Gap=%d Hold=%d Shiny=%s",
                profile.id,crc,s.species,s.temporary_species,s.level,s.hp,s.max_hp,s.battle_type,s.mode,s.started,
                h.plan.delay,h.plan.gap,h.plan.hold,tostring(h.last.shiny))
        end
        console:log(text)
        display(h)
        if log then assert(log:write(os.date("!%Y-%m-%dT%H:%M:%SZ"),"\n",text,"\n\n")); assert(log:flush()) end
    end
    return {
        time=os.time, sample=sample, keys=function(keys) emu:setKeys(keys) end,
        -- Restore RTC; exclude cheats and SAVEDATA writeback. mGBA still restores
        -- embedded SRAM using a temporary mask when flag 2 is absent.
        load=function()
            local ok=emu:loadStateBuffer(baseline,9)
            previous_frame=emu:currentFrame()
            just_loaded=true
            return ok
        end,
        check_frame=function()
            local frame=emu:currentFrame()
            -- GB's frame callback runs BEFORE its frame counter increments.
            -- First callback after an out-of-callback load may have the same count.
            assert(previous_frame==nil or frame==(previous_frame+1)%4294967296 or (just_loaded and frame==previous_frame),
                "Unexpected frame jump: manual state load/reset or skipped callback")
            previous_frame=frame
            just_loaded=false
        end,
        capture=function() return emu:saveStateBuffer(27) end,
        save=function(data) return Storage.save(shiny_path,data) end,
        report=report, display=display,
        close=function() if log then log:close(); log=nil end end,
        screenshot=config.screenshot and function()
            local path=shiny_path..".png"
            assert(not Storage.exists(path),"Screenshot destination exists")
            emu:screenshot(path)
            assert(Storage.exists(path),"Screenshot was not written")
        end or nil,
    },profile
end
return M
