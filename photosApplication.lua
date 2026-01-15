---@class MediaItem
---@field keywords string[] | nil?
---@field name string? -- AKA the title
---@field description string?
---@field favorite boolean?
---@field date number? -- in seconds since unix epoch
---@field id string? -- includes a suffix starting with /
---@field height number? -- in pixels
---@field width number? -- in pixels
---@field filename string -- no directory information
---@field altitude number?
---@field size number? -- in bytes
---@field location [ number, number ]? -- latitude, longitude

---@alias MediaItemKey
---| 'keywords' | 'name' | 'description' | 'favorite' | 'date' | 'id'
---| 'height' | 'width' | 'filename' | 'altitude' | 'size' | 'location'

local Photos = {}

---@vararg MediaItemKey? a list of properties to retrieve, nil for all
---@return {}|[MediaItem]? selection empty table if no selection, nil on error
---@return string|table error raw data string or error table returned by osascript
function Photos.selection(...)
	local _, array, err = hs.osascript.javascript(
		[[
const getProp=(item,propName)=>{
	let value
	try {
		value = item[propName]()
	}
	catch {
		value = Application("Photos").mediaItems.byId(
			Automation.getDisplayString(item).match(
				/mediaItems\.byId\("([^"]+)"\)/
			)[1]
		)[propName]()
	}
	if ( value?.date ) {
		value.date=Math.floor(value.date.getTime()/1000)
	} else if ( propName =="date") {
		value=Math.floor(value.getTime()/1000)
	}
	return value
}
const getProps=(propNames)=> Application("Photos").selection().map(
	(item) => propNames.length ? propNames.reduce(
		(values, propName) => {
			values[propName]=getProp(item,propName)
			return values
		}, {}
	) : getProp(item,"properties")
)
getProps(]] .. hs.json.encode{ ... } .. ')'
	)
	return array, err
end

return Photos
