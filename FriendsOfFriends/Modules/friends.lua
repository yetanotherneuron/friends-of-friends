FOF = FOF or {}

local Saved_AddFriend
local Saved_RemoveFriend

local friendsAtLogin = {}
local savedCurrentFriends = {}
local pendingFriendAdds = {}
local sessionReady = false
local savedPlayerName

function FOF.HookFriendApis()
	if Saved_AddFriend then
		return
	end
	Saved_AddFriend = AddFriend
	Saved_RemoveFriend = RemoveFriend
	AddFriend = FOF.AddFriend
	RemoveFriend = FOF.RemoveFriend
end

function FOF.CurrentFriends()
	local cur = {}
	local n = GetNumFriends()
	for i = 1, n do
		local name = FOF.NormalizeName(GetFriendInfo(i))
		if name then
			cur[name] = name
		end
	end
	return cur
end

function FOF.FriendsDiff()
	local key = FOF.sessionKey
	local cur = FOF.CurrentFriends()
	local player = FOF.NormalizeName(UnitName("player"))
	local globalFriends = FOF.Bucket("friends", key) or {}
	local removed = FOF.Bucket("removedFriends", key) or {}
	local alts = FOF.Bucket("alts", key) or {}

	local toAdd = 0
	local toRemove = 0

	for _, raw in pairs(globalFriends) do
		local name = FOF.NormalizeName(raw)
		if name and name ~= player and not cur[name] and not removed[name] and not alts[name] then
			toAdd = toAdd + 1
		end
	end
	for _, raw in pairs(removed) do
		local name = FOF.NormalizeName(raw)
		if name and name ~= player and cur[name] and not alts[name] then
			toRemove = toRemove + 1
		end
	end

	return toAdd, toRemove
end

function FOF.PendingFriendImportCount()
	local add = FOF.FriendsDiff()
	return add
end

function FOF.SeedFriendsFromCurrent()
	local key = FOF.sessionKey
	local cur = FOF.CurrentFriends()
	FOF_DB.friends[key] = FOF.CopyNameSet(cur)
	FOF_DB.removedFriends[key] = {}
	FOF.ProcessAlts(cur)
end

function FOF.ResetFriendsFromCurrent()
	local key = FOF.sessionKey
	if not key then
		FOF.PrintKey("NEED_LOGIN")
		return
	end
	FOF_DB.friends[key] = FOF.CurrentFriends()
	FOF_DB.removedFriends[key] = {}
	FOF.PrintKey("FRIENDS_RESET")
end

function FOF.ClearGlobalFriends()
	local key = FOF.sessionKey
	if not key then
		FOF.PrintKey("NEED_LOGIN")
		return
	end
	FOF_DB.friends[key] = {}
	FOF_DB.removedFriends[key] = {}
	FOF.PrintKey("FRIENDS_CLEARGLOBAL")
end

function FOF.ClearLocalFriends()
	local key = FOF.sessionKey
	local cur = FOF.CurrentFriends()
	local player = FOF.NormalizeName(UnitName("player"))
	local alts = FOF.Bucket("alts", key) or {}
	local autoAlts = FOF.Get("autoAlts")
	local removed = 0

	for _, name in pairs(cur) do
		if name ~= player and not (autoAlts and alts[name]) then
			Saved_RemoveFriend(name)
			removed = removed + 1
		end
	end
	FOF.PrintKey("FRIENDS_CLEARLOCAL", removed)
end

function FOF.ProcessAlts(curFriends)
	local key = FOF.sessionKey
	curFriends = curFriends or FOF.CurrentFriends()
	local player = FOF.NormalizeName(UnitName("player"))
	local alts = FOF.Bucket("alts", key)
	local friends = FOF.Bucket("friends", key)
	local removed = FOF.Bucket("removedFriends", key)
	local autoAlts = FOF.Get("autoAlts")

	for _, raw in pairs(alts) do
		local name = FOF.NormalizeName(raw)
		if name then
			if autoAlts then
				if name ~= player and not curFriends[name] then
					FOF.VerbosePrintKey("FRIENDS_AUTO_ALT_ADD", name)
					AddFriend(name)
				end
			else
				if name ~= player and curFriends[name] then
					FOF.VerbosePrintKey("FRIENDS_AUTO_ALT_REMOVE", name)
					RemoveFriend(name)
				end
			end
			friends[name] = nil
			removed[name] = nil
		end
	end

	if player and not alts[player] then
		FOF.VerbosePrintKey("FRIENDS_ALT_REGISTER")
		alts[player] = player
	end
end

function FOF.ImportFriends()
	local key = FOF.sessionKey
	local cur = FOF.CurrentFriends()
	local player = FOF.NormalizeName(UnitName("player"))
	local numFriends = GetNumFriends()
	local added = 0
	local skipped = 0
	local removedCount = 0

	local globalRemoves = FOF.Bucket("removedFriends", key)
	local alts = FOF.Bucket("alts", key)
	local globalFriends = FOF.Bucket("friends", key)

	-- snapshot names to avoid mutating while iterating
	local removeList = {}
	for _, raw in pairs(globalRemoves) do
		local name = FOF.NormalizeName(raw)
		if name then
			removeList[#removeList + 1] = name
		end
	end
	for _, name in ipairs(removeList) do
		if name ~= player and cur[name] and not alts[name] then
			RemoveFriend(name)
			numFriends = numFriends - 1
			cur[name] = nil
			removedCount = removedCount + 1
		end
	end

	local addList = {}
	for _, raw in pairs(globalFriends) do
		local name = FOF.NormalizeName(raw)
		if name then
			addList[#addList + 1] = name
		end
	end
	for _, name in ipairs(addList) do
		if name ~= player and not cur[name] and not globalRemoves[name] and not alts[name] then
			if numFriends < FOF.FRIEND_CAP then
				-- keep in global until FRIENDLIST confirms; no fragile pre-delete
				pendingFriendAdds[name] = name
				AddFriend(name)
				added = added + 1
				numFriends = numFriends + 1
			else
				skipped = skipped + 1
			end
		end
	end

	FOF.ProcessAlts(cur)

	local localCount = GetNumFriends()
	if removedCount > 0 or added > 0 or skipped > 0 then
		FOF.PrintKey("FRIENDS_SYNCED", added, removedCount, skipped, localCount, FOF.FRIEND_CAP)
	elseif not FOF.Get("quiet") then
		FOF.PrintKey("FRIENDS_IMPORTED")
	end
end

function FOF.UpdateGlobalFriends(friendsList)
	if not sessionReady or not FOF.Get("initialized") then
		return
	end
	local key = FOF.sessionKey
	local friends = FOF.Bucket("friends", key)
	local removed = FOF.Bucket("removedFriends", key)
	local alts = FOF.Bucket("alts", key)

	for _, raw in pairs(friendsList) do
		local name = FOF.NormalizeName(raw)
		if name then
			if pendingFriendAdds[name] then
				pendingFriendAdds[name] = nil
			end
			if
				not friendsAtLogin[name]
				and not friends[name]
				and not removed[name]
				and not alts[name]
			then
				FOF.VerbosePrintKey("FRIENDS_ADD_GLOBAL", name)
				friends[name] = name
			end
		end
	end
end

function FOF.OnFriendsEnteringWorld()
	local key = FOF.sessionKey
	sessionReady = false
	friendsAtLogin = {}
	pendingFriendAdds = {}
	savedPlayerName = FOF.NormalizeName(UnitName("player"))
	FOF.EnsureBuckets(key)
end

function FOF.MarkFriendsSessionReady()
	friendsAtLogin = FOF.CurrentFriends()
	savedCurrentFriends = friendsAtLogin
	sessionReady = true
end

function FOF.OnFriendListUpdate()
	if not sessionReady then
		return
	end
	savedCurrentFriends = FOF.CurrentFriends()
	FOF.UpdateGlobalFriends(savedCurrentFriends)
end

function FOF.OnFriendsLeavingWorld()
	-- leave unconfirmed pending adds in the global set (safe import)
	if not FOF.Get("autoAlts") then
		return
	end
	local key = FOF.sessionKey
	if not key then
		return
	end
	local alts = FOF.Bucket("alts", key)
	for _, name in pairs(alts) do
		if name ~= savedPlayerName and not savedCurrentFriends[name] then
			FOF.PrintKey("FRIENDS_DELETED_ALT", name)
			alts[name] = nil
		end
	end
end

function FOF.FriendsSessionReady()
	return sessionReady
end

function FOF.AddFriend(name)
	if not name then
		return
	end
	name = FOF.NormalizeName(name)
	Saved_AddFriend(name)
	local key = FOF.sessionKey
	if key then
		local removed = FOF.Bucket("removedFriends", key)
		if removed then
			removed[name] = nil
		end
	end
end

function FOF.RemoveFriend(nameOrIndex)
	local name
	if type(nameOrIndex) == "string" then
		name = nameOrIndex
	else
		name = GetFriendInfo(nameOrIndex)
	end
	if not name then
		return
	end
	name = FOF.NormalizeName(name)
	Saved_RemoveFriend(name)

	local key = FOF.sessionKey
	if not key then
		return
	end
	local friends = FOF.Bucket("friends", key)
	local removed = FOF.Bucket("removedFriends", key)
	local alts = FOF.Bucket("alts", key)
	if friends then
		friends[name] = nil
	end
	if removed and alts and not alts[name] then
		removed[name] = name
	end
end

function FOF.PrintFriendsStatus()
	local key = FOF.sessionKey
	if not key or key == "" then
		FOF.PrintKey("NEED_LOGIN")
		return
	end
	local localCount = GetNumFriends()
	local globalCount = FOF.TableCount(FOF.Bucket("friends", key))
	local pending = FOF.PendingFriendImportCount()
	local altCount = FOF.TableCount(FOF.Bucket("alts", key))
	local free = FOF.FRIEND_CAP - localCount
	if free < 0 then
		free = 0
	end
	local initText = FOF.Get("initialized") and FOF.T("STATUS_YES") or FOF.T("STATUS_NO")
	local altText = FOF.Get("autoAlts") and FOF.T("STATUS_ON") or FOF.T("STATUS_OFF")
	local quietText = FOF.Get("quiet") and FOF.T("STATUS_ON") or FOF.T("STATUS_OFF")

	FOF.PrintKey("STATUS_HEADER", key)
	FOF.PrintKey("STATUS_INIT", initText)
	FOF.PrintKey("STATUS_LOCAL_FRIENDS", localCount, FOF.FRIEND_CAP, free)
	FOF.PrintKey("STATUS_GLOBAL_FRIENDS", globalCount)
	FOF.PrintKey("STATUS_PENDING_FRIENDS", pending)
	FOF.PrintKey("STATUS_ALTS", altCount, altText)
	FOF.PrintKey("STATUS_QUIET", quietText)
end
