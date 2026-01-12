--- === Photos ===
---
--- Control the Photos application, directly or via an http interface
---
---
--- Notes
---  - some returns of MediaItems and Containers are actually just lists of ids.
---  - when do we fetch the details of objects?
---
---

local Photos = {
	name = 'Photos',
	version = '1.0',
	author = 'Erik Ben Heckman <erik@heckman.ca>',
	description = 'Lua interface to the Photos application.',
	homepage = 'https://github.com/Heckman/Photos.spoon',
	license = 'MIT - https://opensource.org/licenses/MIT',
}
Photos.Objects = dofile(hs.spoons.resourcePath 'objects.lua')
Photos.Application = dofile(hs.spoons.resourcePath 'application.lua')

local server -- only load this if we start

---
--- Methods
-----------

function Photos:init() end

function Photos:start()
	server = dofile(hs.spoons.resourcePath 'server.lua')(Photos)
	server.start()
end

function Photos:stop()
	if server then server:stop() end
end

-- function M:bindHotkeys(mapping)
-- local def = { copy_asset_url =  }
-- hs.spoons.bindHotkeysToSpec(def, mapping)
-- end

---
--- utiliy functions
--- -----------------

---@alias PhotosError [string, table]

---@param message string
function Photos.errorAlert(message)
	local style = {
		strokeWidth = 12,
		strokeColor = { red = 1, alpha = 1 },
		fillColor = { black = 0, alpha = 0.75 },
		textColor = { white = 1, alpha = 1 },
		textFont = '.AppleSystemUIFont',
		textSize = 27,
		radius = 27,
		atScreenEdge = 0,
		fadeInDuration = 0.15,
		fadeOutDuration = 0.15,
		padding = 27,
	}
	hs.alert.show(message, style, 3)
end

---@param jxa string -- javascript to execute
---@return any? -- note that nil may be a successful result
---@overload fun(jxa: string): nil, table -- error always included on failure
function Photos.jxaExec(jxa)
	jxa = 'app=Application("Photos");' .. jxa
	local ok, results, err = hs.osascript.javascript(jxa)
	if ok then return results end
	---@cast err table
	local alert = err.OSAScriptErrorMessageKey:gsub('^Error: ', '')
	local number = err.OSAScriptErrorNumberKey
	err = setmetatable({
		message = string.format('JXA: %s (%s)', alert, number),
		data = { number = number, jxa = jxa },
	}, {
		__tostring = function(self)
			return string.format(
				[[%s
```
%s
```
]],
				self.message,
				self.data.jxa
			)
		end,
	})
	Photos.errorAlert(alert)
	print(err)

	return nil, err
end

Photos.Application(Photos)
Photos.Objects(Photos)

return setmetatable(Photos, { Photos.Application })
