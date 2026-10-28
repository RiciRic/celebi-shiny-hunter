-- Load this file via Tools -> Scripting -> Load Script in mGBA 0.10.5.
local source=debug.getinfo(1,"S").source:gsub("^@",""):gsub("\\","/")
local root=assert(source:match("^(.*)/[^/]+$"),"Load hunter.lua by its full path")
package.path=root.."/lua/?.lua;"..package.path
assert(not CELEBI_HUNTER or not CELEBI_HUNTER.shiny_buffer,
    "A shiny is latched in memory. Preserve it before reloading scripts.")
if CELEBI_STOP then CELEBI_STOP() end
if CELEBI_PROBE_ID then callbacks:remove(CELEBI_PROBE_ID); CELEBI_PROBE_ID=nil end
local config=require("settings").validate(dofile(root.."/lua/config.lua"))
local io_adapter=require("adapter").create(root,config)
local hunter=require("controller").new(config,io_adapter)
CELEBI_HUNTER=hunter -- access status and retained shiny_buffer in the console
function CELEBI_RETRY_SAVE(path)
    assert(hunter.shiny_buffer,"No retained shiny state")
    local saved=require("storage").save(path,hunter.shiny_buffer)
    console:log("Retained shiny state saved: "..saved)
    return saved
end
local callback_ids={}
local function detach()
    for _, id in ipairs(callback_ids) do callbacks:remove(id) end
    callback_ids={}
    io_adapter.close()
end
function CELEBI_STOP()
    if hunter.status~="SHINY" and hunter.status~="ERROR" and hunter.status~="VALIDATED" then
        pcall(function() hunter:stop("STOPPED","Stopped by user") end)
    end
    emu:setKeys(0)
    detach()
end
local function terminal()
    return hunter.status=="SHINY" or hunter.status=="ERROR" or hunter.status=="VALIDATED" or hunter.status=="STOPPED"
end
callback_ids[#callback_ids+1]=callbacks:add("frame",function()
    local ok,err=pcall(function()
        io_adapter.check_frame()
        hunter:tick()
        if not terminal() and hunter.frames%config.status_frames==0 then io_adapter.display(hunter) end
    end)
    if not ok then
        hunter.status="ERROR"; hunter.errors=hunter.errors+1
        hunter.reason=tostring(err); emu:setKeys(0)
        console:error("Hunter halted: "..tostring(err))
    end
    if terminal() then detach() end
end)
for _, event in ipairs({"reset","crashed","shutdown"}) do
    callback_ids[#callback_ids+1]=callbacks:add(event,function()
        pcall(function() hunter:fail("Emulator event: "..event) end)
        CELEBI_STOP()
    end)
end
hunter:start()
if terminal() then detach() else io_adapter.display(hunter) end
