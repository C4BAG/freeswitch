-- ice_recorder.lua
--
-- Records a channel's ICE state to a file, polled every 300 ms.
-- Writes a new snapshot ONLY when the ICE fingerprint changes (hash gating),
-- so a stable call produces no noise and the log is a clean timeline of the
-- significant ICE changes. The recorder stops by itself when the channel ends.
--
-- Start from fs_cli (runs in a background thread, does NOT block the console):
--   luarun ice_recorder.lua <uuid> [logpath] [info|debug]
--
-- Notes:
--   * 'luarun' resolves the script name against FreeSWITCH's script_dir
--     (e.g. conf\scripts). Place this file there, or pass an absolute path.
--   * Output goes to the log file, not to your fs_cli prompt (that is why this
--     is a recorder; for a live on-screen view use ice_poll.ps1 instead).
--   * Default log path (when [logpath] is omitted): ice_<uuid>.log in the
--     directory this script lives in (falls back to FreeSWITCH's script_dir,
--     then to the working directory).
--   * The gating level (info|debug) controls WHICH changes trigger a snapshot:
--       info  = role / ready / rready / selected pair only (quiet)
--       debug = also per-candidate changes (responsive, ready, nominated, ...)
--     The snapshot written is always the full JSON dump.

-- Directory this script resides in; falls back to FreeSWITCH's script_dir,
-- then to the working directory. Used for the default log location.
local function default_log_dir()
    if debug and debug.getinfo then
        local src = debug.getinfo(1, "S").source or ""
        if src:sub(1, 1) == "@" then src = src:sub(2) end
        local d = src:match("^(.*[/\\])")
        if d then return d end
    end
    local ok, sd = pcall(function() return freeswitch.API():execute("global_getvar", "script_dir") end)
    if ok and sd and sd ~= "" and sd:sub(1, 4) ~= "-ERR" then
        if not sd:match("[/\\]$") then sd = sd .. package.config:sub(1, 1) end
        return sd
    end
    return ""   -- relative to the FreeSWITCH working directory
end

local uuid  = argv[1]
local level = argv[3] or "info"
local path  = argv[2] or (default_log_dir() .. "ice_" .. tostring(uuid) .. ".log")
local interval_ms = 300

if not uuid or uuid == "" then
    freeswitch.consoleLog("err", "ice_recorder: missing uuid argument\n")
    return
end

local f, err = io.open(path, "a")
if not f then
    freeswitch.consoleLog("err", "ice_recorder: cannot open " .. path .. ": " .. tostring(err) .. "\n")
    return
end

local api  = freeswitch.API()
local last = ""

freeswitch.consoleLog("notice", "ice_recorder: recording " .. uuid .. " (" .. level .. ") -> " .. path .. "\n")

while api:execute("uuid_exists", uuid) == "true" do
    local h = api:execute("uuid_dump_ice", uuid .. " hash " .. level)
    if h and h:sub(1, 4) ~= "-ERR" and h ~= last then
        last = h
        local ts   = os.date("!%Y-%m-%dT%H:%M:%SZ")             -- UTC timestamp
        local dump = api:execute("uuid_dump_ice", uuid .. " json")
        f:write(ts .. " " .. dump .. "\n")
        f:flush()
    end
    freeswitch.msleep(interval_ms)
end

f:close()
freeswitch.consoleLog("notice", "ice_recorder: channel " .. uuid .. " gone, stopped\n")
