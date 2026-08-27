--- @sync entry
-- Persistent tab session: `plugin tab-session` restores the saved tabs, then
-- keeps the state file in sync on every cd/tab event, so the session survives
-- any exit path (q, closing tabs, killing the window).
--
-- Autosave arms only after a restore: instances that never restore (ad-hoc
-- `yazi` in a terminal) can't clobber the session, and neither can a launch
-- whose restore never ran.
--
-- State file: first line is the active tab number, then one cwd per line.

local STATE_FILE = os.getenv("HOME") .. "/.local/state/yazi/session-tabs"

local armed = false

local function save()
	local lines = { tostring(cx.tabs.idx) }
	for _, tab in ipairs(cx.tabs) do
		lines[#lines + 1] = tostring(tab.current.cwd)
	end

	local f = io.open(STATE_FILE .. ".tmp", "w")
	if not f then
		return
	end
	f:write(table.concat(lines, "\n"), "\n")
	f:close()
	os.rename(STATE_FILE .. ".tmp", STATE_FILE)
end

local function read_state()
	local f = io.open(STATE_FILE, "r")
	if not f then
		return nil
	end

	local active = tonumber(f:read("*l"))
	local cwds = {}
	for line in f:lines() do
		if line ~= "" then
			cwds[#cwds + 1] = line
		end
	end
	f:close()

	if not active or #cwds == 0 then
		return nil
	end
	return active, cwds
end

local function entry()
	local active, cwds = read_state()

	if cwds then
		for _ = 1, #cx.tabs - 1 do
			ya.emit("tab_close", { 0 })
		end
		for index, cwd in ipairs(cwds) do
			ya.emit("tab_create", { cwd })
			if index == 1 then
				ya.emit("tab_close", { 0 })
			end
		end
		ya.emit("tab_switch", { active - 1 })
	end

	if not armed then
		armed = true
		ps.sub("cd", save)
		ps.sub("tab", save)
	end
end

return { entry = entry }
