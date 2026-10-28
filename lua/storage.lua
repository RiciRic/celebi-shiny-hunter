-- Windows rename refuses an existing destination (unlike POSIX rename).
-- Never use emu:saveStateFile on the final path: it opens with O_TRUNC.
local M = {}
function M.exists(path)
    local f = io.open(path,"rb")
    if f then f:close(); return true end
    -- A read failure is NOT proof of absence. rename(path,path) also sees
    -- existing unreadable files/directories on Windows.
    local ok, _, code = os.rename(path,path)
    if ok or code==13 then return true end
    assert(code==2, "Cannot establish destination absence: "..path)
    return false
end
function M.preflight(path)
    assert(package.config:sub(1,1)=="\\", "Safe state publication currently supports Windows only")
    assert(not M.exists(path), "Destination already exists: "..path)
end
function M.save(path, data)
    M.preflight(path)
    assert(type(data)=="string" and #data>0, "Empty savestate buffer")
    -- Keep the staging file on the destination volume (Windows rename cannot
    -- cross volumes). A unique OS-generated suffix avoids shared temp names.
    local temporary = os.tmpname()
    local suffix = temporary:match("[^/\\]+$")
    os.remove(temporary)
    local staging = path.."."..suffix..".pending"
    assert(not M.exists(staging), "Staging collision: "..staging)
    local f = assert(io.open(staging,"wb"))
    local ok, err = f:write(data)
    local closed, close_err = f:close()
    assert(ok and closed, "State write failed: "..tostring(err or close_err).."; staging="..staging)
    local check = assert(io.open(staging,"rb"))
    local written = check:read("*a"); check:close()
    assert(written==data, "State verification failed; staging="..staging)
    -- Recheck AND rely on Windows' non-replacing rename for concurrent writers.
    assert(not M.exists(path), "Destination appeared during save; staging="..staging)
    local renamed, rename_err = os.rename(staging,path)
    assert(renamed, "Publish failed: "..tostring(rename_err).."; staging="..staging)
    return path
end
return M
