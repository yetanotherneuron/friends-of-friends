FOF = FOF or {}

FOF.FRIEND_CAP = 50

local defaults = {
	initialized = false,
	quiet = false,
	autoAlts = true,
	friends = {},
	removedFriends = {},
	ignores = {},
	removedIgnores = {},
	alts = {},
}

local listKeys = {
	"friends",
	"removedFriends",
	"ignores",
	"removedIgnores",
	"alts",
}

function FOF.EnsureConfig()
	if type(FOF_DB) ~= "table" then
		FOF_DB = {}
	end
	for key, value in pairs(defaults) do
		if FOF_DB[key] == nil then
			if type(value) == "table" then
				FOF_DB[key] = {}
			else
				FOF_DB[key] = value
			end
		end
	end
	for _, key in ipairs(listKeys) do
		if type(FOF_DB[key]) ~= "table" then
			FOF_DB[key] = {}
		end
	end
	-- legacy: if someone already has list data, treat as initialized
	if not FOF_DB.initialized and next(FOF_DB.friends) then
		FOF_DB.initialized = true
	end
end

function FOF.Get(key)
	return FOF_DB[key]
end

function FOF.Set(key, value)
	FOF_DB[key] = value
	return value
end

function FOF.Toggle(key)
	FOF_DB[key] = not FOF_DB[key]
	return FOF_DB[key]
end

function FOF.RealmFaction()
	local realm = GetRealmName() or ""
	local faction = UnitFactionGroup("player") or ""
	return realm .. "-" .. faction
end

function FOF.EnsureBuckets(key)
	key = key or FOF.sessionKey
	if not key or key == "" then
		return
	end
	for _, mapName in ipairs(listKeys) do
		if type(FOF_DB[mapName][key]) ~= "table" then
			FOF_DB[mapName][key] = {}
		end
		FOF_DB[mapName][key][UNKNOWN] = nil
	end
end

function FOF.Bucket(mapName, key)
	key = key or FOF.sessionKey
	if not key then
		return nil
	end
	FOF.EnsureBuckets(key)
	return FOF_DB[mapName][key]
end

function FOF.TableCount(tbl)
	if not tbl then
		return 0
	end
	local n = 0
	for _ in pairs(tbl) do
		n = n + 1
	end
	return n
end

function FOF.NormalizeName(name)
	if not name or name == "" then
		return nil
	end
	name = strlower(name)
	name = string.match(name, "([^%-]+)") or name
	return string.gsub(name, "^%l", string.upper)
end

function FOF.CopyNameSet(src)
	local out = {}
	if not src then
		return out
	end
	for _, name in pairs(src) do
		if name and name ~= UNKNOWN then
			out[name] = name
		end
	end
	return out
end

function FOF.WipeAll()
	FOF.Set("initialized", false)
	FOF_DB.friends = {}
	FOF_DB.removedFriends = {}
	FOF_DB.ignores = {}
	FOF_DB.removedIgnores = {}
	FOF_DB.alts = {}
	FOF.EnsureConfig()
	if FOF.ResetSessionState then
		FOF.ResetSessionState()
	end
end
