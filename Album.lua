--- @class Album
--- @field id string
--- @field name string
--- @field parent string? -- id of parent
--- @field mediaItems string[] -- list of ids
Album = {}

---@enum Album.Prop
Album.PROPS = {
	'id',
	'name',
	'parent',
	'mediaItems',
}

local propsGen = {
	id = { 'id()', nil },
	name = { 'name()', nil },
	parent = { 'parent()?.id()', nil },
	mediaItems = { 'mediaItems().map((o)=>o.id())', nil },
}


local function setAllProps(self)
	for prop, g in pairs(propsGen) do
		set_fetched_prop(self, prop, g[1])
	end


local function props(id)
	local ok, props, err = hs.osascript.javascript(string.format(
		[[
const album = Application("Photos").albums.byId("%s");
album ? {
		id: album.id(),
		name: album.name(),
		parent_id: album.parent()?.id(),
		mediaItems: album.mediaItems().map((o)=>o.id())

} : null; ]],
		id
	))
	if not ok then
		spoon.Photos:error_alert(err)
		return nil
	end
	--- @cast props table
	props.id = id
	props.bid = getBid(id)
	props.date = props.date and ms2sec(props.date)
	props.undefined = {}
	for _, p in ipairs {
		'keywords',
		'name',
		'description',
		'favorite',
		'date',
		'height',
		'width',
		'filename',
		'altitude',
		'size',
		'location',
	} do
		if props[p] == nil then props.undefined[p] = true end
	end
	return props
end
function ablum.new(id) 88{

}

return setmetatable(album, {
	__call = function(_, ...) return album.new(...) end,
})
