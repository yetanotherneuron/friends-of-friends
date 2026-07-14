FOF = FOF or {}

local function trim(s)
	if not s then
		return ""
	end
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function parseOnOff(token)
	if not token or token == "" then
		return nil
	end
	token = strlower(token)
	if token == "on" or token == "1" or token == "true" then
		return true
	end
	if token == "off" or token == "0" or token == "false" then
		return false
	end
	return nil
end

local function parse(msg)
	msg = strlower(trim(msg))
	local cmd, param = string.match(msg, "^(%S+)%s+(.+)$")
	if not cmd then
		cmd = msg
		param = ""
	end
	return cmd or "", param or ""
end

local function setQuiet(param)
	if param == "" then
		FOF.Toggle("quiet")
	else
		local value = parseOnOff(param)
		if value == nil then
			FOF.PrintKey("QUIET_BAD")
			return
		end
		FOF.Set("quiet", value)
	end
	if FOF.Get("quiet") then
		FOF.PrintKey("QUIET_ON")
	else
		FOF.PrintKey("QUIET_OFF")
	end
end

local function setAlts(param)
	local before = FOF.Get("autoAlts")
	if param == "" then
		FOF.Toggle("autoAlts")
	else
		local value = parseOnOff(param)
		if value == nil then
			FOF.PrintKey("ALTS_BAD")
			return
		end
		FOF.Set("autoAlts", value)
	end
	if FOF.Get("autoAlts") then
		FOF.PrintKey("ALTS_ON")
	else
		FOF.PrintKey("ALTS_OFF")
	end
	if before ~= FOF.Get("autoAlts") then
		FOF.ProcessAlts(FOF.CurrentFriends())
	end
end

local function printFriendsHelp()
	FOF.PrintKey("HELP_HEADER")
	local line = FOF.T("HELP_LINE")
	local function row(cmd, key)
		FOF.Print(string.format(line, cmd, FOF.T(key)))
	end
	row("<help>", "HELP_HELP")
	row("status", "HELP_STATUS")
	row("sync", "HELP_SYNC")
	row("keep", "HELP_KEEP")
	row("reset", "HELP_RESET")
	row("quiet", "HELP_QUIET")
	row("quiet on|off", "HELP_QUIET_SET")
	row("verbose", "HELP_VERBOSE")
	row("wipe", "HELP_WIPE")
	row("alts", "HELP_ALTS")
	row("alts on|off", "HELP_ALTS_SET")
	row("clearglobal", "HELP_CLEARGLOBAL")
	row("clearlocal", "HELP_CLEARLOCAL")
	row("ignore ...", "HELP_IGNORE")
	FOF.PrintKey("HELP_ALIAS")
end

local function printIgnoreHelp()
	FOF.PrintKey("HELP_IGNORE_HEADER")
	local line = FOF.T("HELP_IGNORE_LINE")
	local function row(cmd, key)
		FOF.Print(string.format(line, cmd, FOF.T(key)))
	end
	row("<help>", "HELP_IGNORE_HELP")
	row("status", "HELP_IGNORE_STATUS")
	row("sync", "HELP_IGNORE_SYNC")
	row("reset", "HELP_IGNORE_RESET")
	row("quiet", "HELP_IGNORE_QUIET")
	row("quiet on|off", "HELP_IGNORE_QUIET_SET")
	row("verbose", "HELP_IGNORE_VERBOSE")
	row("clearglobal", "HELP_IGNORE_CLEARGLOBAL")
	row("clearlocal", "HELP_IGNORE_CLEARLOCAL")
end

function FOF.IgnoreCommand(msg)
	FOF.Initialise()
	local cmd, param = parse(msg)
	if cmd == "" or cmd == "help" then
		printIgnoreHelp()
		return
	end
	if cmd == "status" then
		FOF.PrintIgnoresStatus()
		return
	end
	if cmd == "sync" or cmd == "import" then
		FOF.ImportIgnores()
		return
	end
	if cmd == "reset" then
		FOF.ResetIgnoresFromCurrent()
		return
	end
	if cmd == "quiet" then
		setQuiet(param)
		return
	end
	if cmd == "verbose" then
		FOF.Set("quiet", false)
		FOF.PrintKey("QUIET_OFF")
		return
	end
	if cmd == "clearglobal" then
		FOF.ClearGlobalIgnores()
		return
	end
	if cmd == "clearlocal" then
		FOF.ClearLocalIgnores()
		return
	end
	FOF.PrintKey("UNKNOWN_IGNORE_CMD")
end

function FOF.Command(msg)
	FOF.Initialise()
	local cmd, param = parse(msg)
	if cmd == "" or cmd == "help" then
		printFriendsHelp()
		return
	end
	if cmd == "ignore" then
		FOF.IgnoreCommand(param)
		return
	end
	if cmd == "status" then
		FOF.PrintFriendsStatus()
		return
	end
	if cmd == "sync" or cmd == "import" then
		FOF.SyncAll()
		return
	end
	if cmd == "keep" then
		FOF.KeepLocal()
		return
	end
	if cmd == "reset" then
		FOF.ResetFriendsFromCurrent()
		return
	end
	if cmd == "quiet" then
		setQuiet(param)
		return
	end
	if cmd == "verbose" then
		FOF.Set("quiet", false)
		FOF.PrintKey("QUIET_OFF")
		return
	end
	if cmd == "wipe" then
		FOF.WipeAll()
		FOF.PrintKey("WIPE_DONE")
		return
	end
	if cmd == "alts" then
		setAlts(param)
		return
	end
	if cmd == "clearglobal" then
		FOF.ClearGlobalFriends()
		return
	end
	if cmd == "clearlocal" then
		FOF.ClearLocalFriends()
		return
	end
	FOF.PrintKey("UNKNOWN_CMD")
end

SlashCmdList["FRIENDSOFFRIENDS"] = function(msg)
	FOF.Command(msg)
end
SLASH_FRIENDSOFFRIENDS1 = "/fof"
SLASH_FRIENDSOFFRIENDS2 = "/friendsoffriends"

SlashCmdList["FRIENDSOFFRIENDSIGNORE"] = function(msg)
	FOF.IgnoreCommand(msg)
end
SLASH_FRIENDSOFFRIENDSIGNORE1 = "/foi"
