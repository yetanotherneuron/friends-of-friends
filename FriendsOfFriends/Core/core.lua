FOF = FOF or {}
FOF.VERSION = "1.0.0"

local initialised = false

function FOF.Print(msg)
	local p = FOF.Palette
	local prefix = "FriendsOfFriends"
	if FOF.T then
		prefix = FOF.T("PREFIX")
	end
	DEFAULT_CHAT_FRAME:AddMessage(
		p.brand .. prefix .. " : " .. p.body .. tostring(msg) .. p.reset
	)
end

function FOF.PrintKey(key, ...)
	FOF.Print(FOF.T(key, ...))
end

function FOF.VerbosePrint(msg)
	if not FOF.Get("quiet") then
		FOF.Print(msg)
	end
end

function FOF.VerbosePrintKey(key, ...)
	if not FOF.Get("quiet") then
		FOF.PrintKey(key, ...)
	end
end

function FOF.Initialise()
	if initialised then
		return
	end
	initialised = true
	FOF.EnsureConfig()
	FOF.LoadLocale()
	FOF.HookFriendApis()
	FOF.HookIgnoreApis()
	FOF.RegisterSyncConfirm()
end

function FOF_OnLoad()
	this:RegisterEvent("ADDON_LOADED")
	this:RegisterEvent("PLAYER_ENTERING_WORLD")
	this:RegisterEvent("PLAYER_LEAVING_WORLD")
	this:RegisterEvent("FRIENDLIST_UPDATE")
	this:RegisterEvent("IGNORELIST_UPDATE")
end

function FOF_OnEvent()
	if event == "ADDON_LOADED" then
		if arg1 == "FriendsOfFriends" then
			FOF.Initialise()
		end
		return
	end

	if event == "PLAYER_ENTERING_WORLD" then
		if not initialised then
			FOF.Initialise()
		end
		FOF.OnPromptEnteringWorld()
		return
	end

	if event == "FRIENDLIST_UPDATE" then
		FOF.OnPromptFriendListUpdate()
		return
	end

	if event == "IGNORELIST_UPDATE" then
		FOF.OnPromptIgnoreListUpdate()
		return
	end

	if event == "PLAYER_LEAVING_WORLD" then
		FOF.OnFriendsLeavingWorld()
		return
	end
end
