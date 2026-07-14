FOF = FOF or {}

local Saved_AddIgnore
local Saved_DelIgnore

local ignoresAtLogin = {}
local ignoreSessionReady = false

function FOF.HookIgnoreApis()
	if Saved_AddIgnore then
		return
	end
	Saved_AddIgnore = AddIgnore
	Saved_DelIgnore = DelIgnore
	AddIgnore = FOF.AddIgnore
	DelIgnore = FOF.DelIgnore
end

function FOF.CurrentIgnores()
	local cur = {}
	local n = GetNumIgnores()
	for i = 1, n do
		local name = GetIgnoreName(i)
		if name and name ~= UNKNOWN then
			cur[name] = name
		end
	end
	return cur
end

function FOF.IgnoresDiff()
	local key = FOF.sessionKey
	local cur = FOF.CurrentIgnores()
	local player = UnitName("player")
	local globalIgnores = FOF.Bucket("ignores", key) or {}
	local removed = FOF.Bucket("removedIgnores", key) or {}

	local toAdd = 0
	local toRemove = 0

	for _, name in pairs(globalIgnores) do
		if name ~= player and not cur[name] and not removed[name] then
			toAdd = toAdd + 1
		end
	end
	for _, name in pairs(removed) do
		if name ~= player and cur[name] then
			toRemove = toRemove + 1
		end
	end

	return toAdd, toRemove
end

function FOF.PendingIgnoreImportCount()
	local add = FOF.IgnoresDiff()
	return add
end

function FOF.SeedIgnoresFromCurrent()
	local key = FOF.sessionKey
	FOF_DB.ignores[key] = FOF.CopyNameSet(FOF.CurrentIgnores())
	FOF_DB.removedIgnores[key] = {}
end

function FOF.ResetIgnoresFromCurrent()
	local key = FOF.sessionKey
	if not key then
		FOF.PrintKey("NEED_LOGIN")
		return
	end
	FOF_DB.ignores[key] = FOF.CurrentIgnores()
	FOF_DB.removedIgnores[key] = {}
	FOF.PrintKey("IGNORES_RESET")
end

function FOF.ClearGlobalIgnores()
	local key = FOF.sessionKey
	if not key then
		FOF.PrintKey("NEED_LOGIN")
		return
	end
	FOF_DB.ignores[key] = {}
	FOF_DB.removedIgnores[key] = {}
	FOF.PrintKey("IGNORES_CLEARGLOBAL")
end

function FOF.ClearLocalIgnores()
	local cur = FOF.CurrentIgnores()
	local removed = 0
	for _, name in pairs(cur) do
		Saved_DelIgnore(name)
		removed = removed + 1
	end
	FOF.PrintKey("IGNORES_CLEARLOCAL", removed)
end

function FOF.ImportIgnores()
	local key = FOF.sessionKey
	local cur = FOF.CurrentIgnores()
	local player = UnitName("player")
	local added = 0
	local removedCount = 0

	local globalIgnores = FOF.Bucket("ignores", key)
	local globalRemoves = FOF.Bucket("removedIgnores", key)

	-- remove first (same order as friends import)
	local removeList = {}
	for _, name in pairs(globalRemoves) do
		removeList[#removeList + 1] = name
	end
	for _, name in ipairs(removeList) do
		if name ~= player and cur[name] then
			globalIgnores[name] = nil
			DelIgnore(name)
			cur[name] = nil
			removedCount = removedCount + 1
		end
	end

	local addList = {}
	for _, name in pairs(globalIgnores) do
		addList[#addList + 1] = name
	end
	for _, name in ipairs(addList) do
		if name ~= player and not cur[name] and not globalRemoves[name] then
			FOF.VerbosePrintKey("IGNORES_TRY_ADD", name)
			AddIgnore(name)
			added = added + 1
		end
	end

	if added > 0 or removedCount > 0 then
		FOF.PrintKey("IGNORES_SYNCED", added, removedCount, GetNumIgnores())
	elseif not FOF.Get("quiet") then
		FOF.PrintKey("IGNORES_IMPORTED")
	end
end

function FOF.UpdateGlobalIgnores(ignoresList)
	if not FOF.Get("initialized") or not ignoreSessionReady then
		return
	end
	local key = FOF.sessionKey
	local ignores = FOF.Bucket("ignores", key)
	local removed = FOF.Bucket("removedIgnores", key)

	for _, name in pairs(ignoresList) do
		if not ignoresAtLogin[name] and not ignores[name] and not removed[name] then
			FOF.VerbosePrintKey("IGNORES_ADD_GLOBAL", name)
			ignores[name] = name
		end
	end
end

function FOF.OnIgnoresEnteringWorld()
	ignoreSessionReady = false
	ignoresAtLogin = {}
	FOF.EnsureBuckets(FOF.sessionKey)
end

function FOF.MarkIgnoresSessionReady()
	ignoresAtLogin = FOF.CurrentIgnores()
	ignoreSessionReady = true
end

function FOF.OnIgnoreListUpdate()
	if not ignoreSessionReady then
		return
	end
	FOF.UpdateGlobalIgnores(FOF.CurrentIgnores())
end

function FOF.AddIgnore(name)
	if not name then
		return
	end
	name = FOF.NormalizeName(name)
	Saved_AddIgnore(name)
	local key = FOF.sessionKey
	if key then
		local removed = FOF.Bucket("removedIgnores", key)
		if removed then
			removed[name] = nil
		end
	end
end

function FOF.DelIgnore(nameOrIndex)
	local name
	if type(nameOrIndex) == "string" then
		name = nameOrIndex
	else
		name = GetIgnoreName(nameOrIndex)
	end
	if not name then
		return
	end
	name = FOF.NormalizeName(name)
	Saved_DelIgnore(name)

	local key = FOF.sessionKey
	if not key then
		return
	end
	local ignores = FOF.Bucket("ignores", key)
	local removed = FOF.Bucket("removedIgnores", key)
	if ignores then
		ignores[name] = nil
	end
	if removed then
		removed[name] = name
	end
end

function FOF.PrintIgnoresStatus()
	local key = FOF.sessionKey
	if not key or key == "" then
		FOF.PrintKey("NEED_LOGIN")
		return
	end
	local localCount = GetNumIgnores()
	local globalCount = FOF.TableCount(FOF.Bucket("ignores", key))
	local pending = FOF.PendingIgnoreImportCount()
	local initText = FOF.Get("initialized") and FOF.T("STATUS_YES") or FOF.T("STATUS_NO")
	local quietText = FOF.Get("quiet") and FOF.T("STATUS_ON") or FOF.T("STATUS_OFF")

	FOF.PrintKey("IGNORE_STATUS_HEADER", key)
	FOF.PrintKey("STATUS_INIT", initText)
	FOF.PrintKey("IGNORE_STATUS_LOCAL", localCount)
	FOF.PrintKey("IGNORE_STATUS_GLOBAL", globalCount)
	FOF.PrintKey("IGNORE_STATUS_PENDING", pending)
	FOF.PrintKey("STATUS_QUIET", quietText)
end
