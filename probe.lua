-- Read-only prototype. Load during a naturally initialized Celebi encounter.
local source=debug.getinfo(1,"S").source:gsub("^@",""):gsub("\\","/")
local root=assert(source:match("^(.*)/[^/]+$"),"Load probe.lua by its full path")
package.path=root.."/lua/?.lua;"..package.path
if CELEBI_STOP then CELEBI_STOP() end
if CELEBI_PROBE_ID then callbacks:remove(CELEBI_PROBE_ID) end
local config=dofile(root.."/lua/config.lua")
local profile,sample=require("adapter").connect(config.rom)
local detector=require("detector")
local last
CELEBI_PROBE_ID=callbacks:add("frame",function()
    local ok,err=pcall(function()
        local s=sample()
        local dv=detector.dvs(s.dv1,s.dv2)
        local message=string.format("%s: mode=%d type=%d started=%d species=%d temp=%d level=%d HP=%d/%d DVs=%d/%d/%d/%d raw=%s shiny=%s",
            profile.id,s.mode,s.battle_type,s.started,s.species,s.temporary_species,s.level,s.hp,s.max_hp,
            dv.attack,dv.defense,dv.speed,dv.special,dv.key,tostring(dv.shiny))
        if message~=last then
            console:log(message.." [read-only sample; freshness not established]")
            last=message
        end
    end)
    if not ok then console:error(tostring(err)); callbacks:remove(CELEBI_PROBE_ID); CELEBI_PROBE_ID=nil end
end)
