FOF = FOF or {}

function FOF.LoadLocale()
	local L = {}
	if type(FOF_Locale_enUS) == "table" then
		for key, value in pairs(FOF_Locale_enUS) do
			L[key] = value
		end
	end
	FOF.L = L
end

function FOF.T(key, ...)
	local text = (FOF.L and FOF.L[key]) or key
	if select("#", ...) > 0 then
		return string.format(text, ...)
	end
	return text
end
