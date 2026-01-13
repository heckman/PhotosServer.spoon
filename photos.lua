local Photos = {}

---@param jxa string -- javascript to execute
---@return any? -- note that nil may be a successful result
---@overload fun(jxa: string): nil, table -- error always included on failure

local JXA = {}
function JXA.exec(jxa)
	local ok, results, err = hs.osascript.javascript(jxa)
	if ok then return results end
	---@cast err table
	local alert = err.OSAScriptErrorMessageKey:gsub('^Error: ', '')
	local number = err.OSAScriptErrorNumberKey
	err = setmetatable({
		message = string.format('JXA: %s (%s)', alert, number),
		data = { number = number, jxa = jxa },
	}, {
		__tostring = function (self)
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
	JXA.alertError(alert)
	print(err)

	return nil, err
end

function JXA.errorAlert(message)
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

local dateFix =
';(function seconds(o){return Array.isArray(o)?o.map(seconds):Math.floor(o.getTime()/1000)}(obj));'

local propertiesFix =
';if(obj.date)obj.date=Math.floor(obj.date.getTime()/1000);obj;'

-- A wrapper that Apllies fixes for date objects
local function jxaExec(jxa)
	return JXA.exec(string.sub(jxa, -7) == '.date()' and
		'obj=' .. jxa .. dateFix or
		string.sub(jxa, -13) == '.properties()' and
		'obj=' .. jxa .. propertiesFix or jxa)
end

return setmetatable(Photos, { __call = Photos.jxaExec })
