FOF = FOF or {}

-- persists across zoning until UI reload / wipe
local askedThisSession = false
local seededThisLogin = false
local awaitingLists = false
local loginGateDone = false
local settleElapsed = 0
local SETTLE_SECONDS = 0.75

function FOF.ResetSessionState()
	askedThisSession = false
	seededThisLogin = false
	awaitingLists = false
	loginGateDone = false
	settleElapsed = 0
	FOF.sessionKey = nil
	if FOF_Frame then
		FOF_Frame:SetScript("OnUpdate", nil)
	end
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
	FOF.ClearKeepSkip(FOF.CharKey())
	FOF.ImportFriends()
	FOF.ImportIgnores()
end

function FOF.KeepLocal()
	FOF.MarkAskedThisSession()
	FOF.HideSyncConfirm()
	FOF.RememberKeepSkip()
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

	-- Keep: skip while shared lists match the signature saved at Keep time
	if FOF.ShouldSkipKeepPrompt() then
		askedThisSession = true
		return
	end

	local hasDiff, fAdd, fRemove, iAdd, iRemove = FOF.HasListDiff()
	if not hasDiff then
		askedThisSession = true
		FOF.ClearKeepSkip(FOF.CharKey())
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
	loginGateDone = true
	settleElapsed = 0
	if FOF_Frame then
		FOF_Frame:SetScript("OnUpdate", nil)
	end

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

local function onSettleUpdate(self, elapsed)
	if not awaitingLists then
		self:SetScript("OnUpdate", nil)
		return
	end
	settleElapsed = settleElapsed + (elapsed or 0)
	if settleElapsed >= SETTLE_SECONDS then
		finishListGate()
	end
end

local function bumpListSettle()
	if not awaitingLists then
		return
	end
	-- debounce: wait until friend/ignore updates stop arriving
	settleElapsed = 0
	if FOF_Frame then
		FOF_Frame:SetScript("OnUpdate", onSettleUpdate)
	else
		finishListGate()
	end
end

function FOF.OnPromptEnteringWorld()
	FOF.sessionKey = FOF.RealmFaction()

	-- zoning / second PEW: do not reset friendsAtLogin or re-prompt
	if loginGateDone then
		return
	end

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

	-- wait for list updates to settle before sessionReady / prompt
	awaitingLists = true
	settleElapsed = 0
	ShowFriends()
	bumpListSettle()
end

function FOF.OnPromptFriendListUpdate()
	if awaitingLists then
		bumpListSettle()
		return
	end
	FOF.OnFriendListUpdate()
end

function FOF.OnPromptIgnoreListUpdate()
	if awaitingLists then
		bumpListSettle()
		return
	end
	FOF.OnIgnoreListUpdate()
end
