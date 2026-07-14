FOF = FOF or {}

-- persists across zoning until UI reload / wipe
local askedThisSession = false
local seededThisLogin = false
local awaitingLists = false

function FOF.ResetSessionState()
	askedThisSession = false
	seededThisLogin = false
	awaitingLists = false
	FOF.sessionKey = nil
end

function FOF.MarkAskedThisSession()
	askedThisSession = true
end

function FOF.WasAskedThisSession()
	return askedThisSession
end

function FOF.SyncAll()
	FOF.MarkAskedThisSession()
	FOF.HideSyncConfirm()
	FOF.ImportFriends()
	FOF.ImportIgnores()
end

function FOF.KeepLocal()
	FOF.MarkAskedThisSession()
	FOF.HideSyncConfirm()
	if not FOF.Get("quiet") then
		FOF.PrintKey("KEEP_DONE")
	end
end

function FOF.HasListDiff()
	local fAdd, fRemove = FOF.FriendsDiff()
	local iAdd, iRemove = FOF.IgnoresDiff()
	return (fAdd + fRemove + iAdd + iRemove) > 0, fAdd, fRemove, iAdd, iRemove
end

function FOF.MaybeShowSyncPrompt()
	if askedThisSession or seededThisLogin then
		return
	end
	if not FOF.Get("initialized") then
		return
	end
	if not FOF.FriendsSessionReady() then
		return
	end

	local hasDiff, fAdd, fRemove, iAdd, iRemove = FOF.HasListDiff()
	if not hasDiff then
		askedThisSession = true
		return
	end

	askedThisSession = true
	FOF.ShowSyncConfirm(fAdd, fRemove, iAdd, iRemove)
end

local function finishListGate()
	if not awaitingLists then
		return
	end
	awaitingLists = false

	if seededThisLogin then
		-- list is populated — refresh the seed from real data once
		FOF.SeedFriendsFromCurrent()
		FOF.SeedIgnoresFromCurrent()
		seededThisLogin = false
	end

	FOF.MarkFriendsSessionReady()
	FOF.MarkIgnoresSessionReady()
	FOF.MaybeShowSyncPrompt()
end

function FOF.OnPromptEnteringWorld()
	FOF.sessionKey = FOF.RealmFaction()
	FOF.OnFriendsEnteringWorld()
	FOF.OnIgnoresEnteringWorld()

	if not FOF.Get("initialized") then
		FOF.SeedFriendsFromCurrent()
		FOF.SeedIgnoresFromCurrent()
		FOF.Set("initialized", true)
		seededThisLogin = true
		askedThisSession = true
		FOF.PrintKey("SEED_DONE")
	end

	-- wait for list update before sessionReady / prompt
	awaitingLists = true
	ShowFriends()
end

function FOF.OnPromptFriendListUpdate()
	if awaitingLists then
		finishListGate()
		return
	end
	FOF.OnFriendListUpdate()
end

function FOF.OnPromptIgnoreListUpdate()
	-- don't finish the login gate here — friends list may still be empty
	if awaitingLists then
		return
	end
	FOF.OnIgnoreListUpdate()
end
