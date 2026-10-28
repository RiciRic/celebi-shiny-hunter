-- Load this script while standing in front of the shrine, before pressing A.
local source=debug.getinfo(1,"S").source:gsub("^@",""):gsub("\\","/")
local root=assert(source:match("^(.*)/[^/]+$"),"Load prepare-state.lua by its full path")
package.path=root.."/lua/?.lua;"..package.path
assert(not CELEBI_HUNTER or not CELEBI_HUNTER.shiny_buffer,
    "A shiny is retained in memory. Preserve it before preparing another state.")
if CELEBI_STOP then CELEBI_STOP() end
local config=dofile(root.."/lua/config.lua")
local adapter=require("adapter")
local profile,sample=adapter.connect(config.rom)
require("detector").overworld(sample())
emu:setKeys(0)
local path=adapter.path(root,config.state)
require("storage").save(path,assert(emu:saveStateBuffer(27),"Cannot capture baseline state"))
console:log("AUSGANGSSPIELSTAND GESPEICHERT: "..path.." ("..profile.id..")")
console:log("Jetzt hunter.lua laden. Voraussetzung: Du standest vor dem Schrein, ohne offenen Dialog.")
