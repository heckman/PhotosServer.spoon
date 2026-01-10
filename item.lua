M = {}

---@class MediaItem
---@field keywords string[] | nil
---@field name string? -- AKA the title
---@field description string?
---@field favorite boolean?
---@field date number? -- in seconds since unix epoch
---@field id string -- includes a suffix starting with /
---@field bid string -- base id (without suffix)
---@field height number? -- in pixels
---@field width number? -- in pixels
---@field filename string -- no directory information
---@field altitude number?
---@field size number? -- in bytes
---@field location [ number, number ] | nil -- latitude, longitude
---@field label string
---@field __nulls table<MediaItem.Prop,true?>
---@field __id string -- with or without suffix, privided to constructor
---@field __type 'MediaItem'|'Album'|'Folder'
---@field PROPS

-- This is ugly but it works.
-- There must be a better way to do this--I tried @enum but had trouble.
---@alias MediaItem.Prop 'keywords'|'name'|'description'|'favorite'|'date'|'id'|'bid'|'height'|'width'|'filename'|'altitude'|'size'|'location'|'label'
local PROPS = {
	MediaItem = {
		'keywords',
		'name',
		'description',
		'favorite',
		'date',
		'id',
		'bid',
		'height',
		'width',
		'filename',
		'altitude',
		'size',
		'location',
		'label',
	},
}
local PGF = {
	FETCH = 1,
	AFTER = 2,
	DERIVE = 3,
	DERARGS = 4,
}
local propsGen = {
	MediaItem = {
		id = { 'id()', nil },
		bid = {
			nil,
			nil,
			function(id) return id:gsub('/.*$', '') end,
			'id',
		},
		keywords = { 'keywords()', nil },
		name = { 'name()', nil },
		description = { 'description()', nil },
		favorite = { 'favorite()', nil },
		date = {
			'date()?.getTime()',
			function(date) return date and math.floor(date / 1000) end,
		},
		height = { 'height()', nil },
		width = { 'width()', nil },
		filename = { 'filename()', nil },
		altitude = { 'altitude()', nil },
		size = { 'size()', nil },
		location = { 'location()', nil },
		label = {
			nil,
			nil,
			function(name, description, keywords, filename)
				return name
					or description
					or keywords and keywords[1]
					or filename:gsub('%.[^.]+$', '')
			end,
			'name',
			'description',
			'keywords',
			'filename',
		},
	},
}
local jxa_fetch = {
	MediaItem = [[
const item = Application("Photos").mediaItems.byId("%s")
item ? { %s } : null; ]],
	Album = [[
const item = Application("Photos").albums.byId("%s")
item ? { %s } : null; ]],
	Folder = [[
const item = Application("Photos").folders.byId("%s")
item ? { %s } : null; ]],
}
---@param prop MediaItem.Prop
---@param prop_def PropDef
local function jxa_prop_def(prop, prop_def)
	return string.format('%s: item.%s', prop, prop_def[PGF.FETCH])
end

---@param self MediaItem
---@param prop MediaItem.Prop
---@return boolean
local is_null = function(self, prop) return self.__nulls[prop] end

---@param self MediaItem
---@param prop MediaItem.Prop
---@param value any
local function set_prop(self, prop, value)
	if value == nil then
		self.__nulls[prop] = true
	else
		self[prop] = value
		return value
	end
end

---@param self MediaItem
---@param prop MediaItem.Prop
---@param value any
local function set_fetched_prop(self, prop, value)
	local g = propsGen[self.__type][prop]
	return set_prop(
		self,
		prop,
		g[PGF.AFTER] and g[PGF.AFTER](value) or value
	)
end

---@param self MediaItem
---@param prop MediaItem.Prop
---@param getter function<MediaItem,...> -- gets the source values
local function set_derived_prop(self, prop, getter)
	local g = propsGen[self.__type][prop]
	return set_prop(
		self,
		prop,
		g[PGF.DERIVE](getter(self, table.unpack(g, PGF.DERARGS)))
	)
end

---@param self MediaItem
---@param ... string passed to string.format
local function die(self, ...) error(string.format(...)) end

---@param self MediaItem
---@param prop MediaItem.Prop
---@param def PropDef
local function die_bad_prop(self, prop, def)
	die(self, "poorly-defined lazy prop '%s': %s", prop, def)
end

---@param self MediaItem only used for error reporting
---@param prop_defs string prop jxa definitions
---@return table<MediaItem.Prop,any>
local function fetch_props(self, prop_defs)
	-- print(string.format(jxa_fetch[self.__type], self.__id, prop_defs))
	local ok, results, err = hs.osascript.javascript(
		string.format(jxa_fetch[self.__type], self.__id, prop_defs)
	)
	if ok then
		---@cast results table
		return results
	else
		--- I'm hoping error_alert from Photos/init.lua will be accessible
		---@diagnostic disable-next-line: undefined-global
		-- spoon.Photos.error_alert(self, err)
		error(string.format('%s:%s', hs.inspect(self), hs.inspect(err)))
		return {}
	end
end

-- local recursion_count = 0
---@param self MediaItem
---@param ... string[] Properties to get, defaults to all MediaItem.PROPS
---@return any ...
local function get_lazy_props(self, ...)
	local props = select('#', ...) > 0 and { ... } or PROPS[self.__type]
	print(hs.inspect(props))
	local jxa_props, jxa_count = {}, 0
	local derived_props, derived_count = {}, 0
	local jxa_prop_defs, results = {}, {}

	for _, p in ipairs(props) do
		local g = propsGen[self.__type][p]
		local raw = rawget(self, p)
		---@diagnostic disable-next-line: param-type-mismatch
		if not g or raw or is_null(self, p) then
			results[p] = rawget(self, p)
		else
			---@cast p MediaItem.Prop
			if g[PGF.FETCH] then
				jxa_count = jxa_count + 1
				jxa_props[jxa_count] = p
				jxa_prop_defs[jxa_count] = jxa_prop_def(p, g)
			elseif g[PGF.DERIVE] then
				derived_count = derived_count + 1
				derived_props[derived_count] = p
			else
				-- either the first or third element must be set
				die_bad_prop(self, p, hs.inspect(g))
			end
		end
	end
	-- fetch all the vales that need fetching then set them
	if jxa_count > 0 then
		local fetched =
			fetch_props(self, table.concat(jxa_prop_defs, ','))
		for i = 1, jxa_count do
			local p = jxa_props[i]
			results[p] = set_fetched_prop(self, p, fetched[p])
		end
	end
	-- set all the derived props after the jxa-defined props
	for i = 1, derived_count do
		local p = derived_props[i]
		results[p] = set_derived_prop(self, p, get_lazy_props)
	end
	local return_values = {}
	for i, prop in ipairs(props) do
		return_values[i] = results[prop]
	end
	print(#props)
	return table.unpack(return_values, 1, #props)
end

---@param self MediaItem
---@param prop string
local function get_freshly_generated_prop(self, prop)
	local g = propsGen[self.__type][prop]
	if not g then return rawget(self, prop) end
	---@cast prop MediaItem.Prop
	if g[PGF.FETCH] then
		local fetched = fetch_props(self, jxa_prop_def(prop, g))
		return set_fetched_prop(self, prop, fetched[prop])
	elseif g[PGF.DERIVE] then
		return set_derived_prop(self, prop, get_lazy_props)
	else
		die_bad_prop(self, prop, g)
	end
end
local lazy_loader = {
	__index = function(self, prop)
		-- sometimes nil is what we want
		if is_null(self, prop) then return nil end
		return get_freshly_generated_prop(self, prop)
	end,
	__call = get_lazy_props,
}

-- public funcitions

function M.get(type, id)
	local object = { __id = id, __nulls = {}, __type = type }
	-- print('OBJECT=', d(object))
	setmetatable(object, lazy_loader)
	get_freshly_generated_prop(object, 'id')
	return object
end
function M.mediaItem(id) return M.get('MediaItem', id) end
function M.album(id) return M.get('MediaItem', id) end
function M.folder(id) return M.get('MediaItem', id) end

return setmetatable(M, {
	__call = function(_, ...) return M.get(...) end,
})
