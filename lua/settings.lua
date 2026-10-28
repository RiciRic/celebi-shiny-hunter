local M = {}
local function integer(n, low, high, name)
    assert(type(n)=="number" and n==math.floor(n) and n>=low and n<=high, "Invalid configuration: "..name)
end
local function gcd(a,b)
    while b~=0 do a,b=b,a%b end
    return a
end
function M.validate(c)
    assert(c.mode=="validate" or c.mode=="hunt", "mode must be validate or hunt")
    assert(c.speed=="frontend", "mGBA 0.10.5 requires frontend speed configuration")
    for _, k in ipairs({"state","shiny"}) do assert(type(c[k])=="string" and #c[k]>0, "Missing path: "..k) end
    assert(c.log==false or type(c.log)=="string", "Invalid log path")
    assert(type(c.screenshot)=="boolean", "Invalid screenshot setting")
    integer(c.timeout_frames,60,1000000,"timeout_frames")
    integer(c.stable_frames,2,10,"stable_frames")
    integer(c.status_frames,1,3600,"status_frames")
    integer(c.validation_encounters,2,1000,"validation_encounters")
    local r=c.rng
    integer(r.delay_count,2,65536,"delay_count")
    integer(r.delay_stride,1,65535,"delay_stride")
    assert(gcd(r.delay_count,r.delay_stride)==1, "delay_stride and delay_count must be coprime")
    integer(r.gap_variants,1,256,"gap_variants")
    integer(r.hold_variants,1,8,"hold_variants")
    integer(r.identical_limit,2,1000,"identical_limit")
    integer(r.window,2,1000,"window")
    integer(r.minimum_unique,2,r.window,"minimum_unique")
    integer(c.controls.base_gap,1,60,"base_gap")
    integer(c.controls.confirm_keys,1,255,"confirm_keys")
    local length=0
    for _, step in ipairs(c.controls.prefix) do
        integer(step.frames,1,3600,"prefix.frames")
        integer(step.keys,0,255,"prefix.keys")
        length=length+step.frames
    end
    assert(length<c.timeout_frames, "Prefix exceeds encounter timeout")
    return c
end
return M
