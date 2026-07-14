FOF = FOF or {}

local POPUP = "FOF_SYNC_CONFIRM"

function FOF.RegisterSyncConfirm()
	StaticPopupDialogs[POPUP] = {
		text = "%s",
		button1 = FOF.T("PROMPT_YES"),
		button2 = FOF.T("PROMPT_NO"),
		OnAccept = function()
			FOF.SyncAll()
		end,
		OnCancel = function()
			FOF.KeepLocal()
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
		showAlert = 1,
	}
end

function FOF.ShowSyncConfirm(fAdd, fRemove, iAdd, iRemove)
	local dialog = StaticPopupDialogs[POPUP]
	if not dialog then
		FOF.RegisterSyncConfirm()
		dialog = StaticPopupDialogs[POPUP]
	end
	dialog.button1 = FOF.T("PROMPT_YES")
	dialog.button2 = FOF.T("PROMPT_NO")

	local p = FOF.Palette
	local title = p.brand .. FOF.T("PROMPT_TITLE") .. p.reset
	local body = FOF.T("PROMPT_BODY", fAdd or 0, fRemove or 0, iAdd or 0, iRemove or 0)
	StaticPopup_Show(POPUP, title .. "\n\n" .. body)
end

function FOF.HideSyncConfirm()
	StaticPopup_Hide(POPUP)
end
