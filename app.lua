M = {}

local jxa_mediaItem = [[
function addDerivedFields(obj){
	obj.bid=obj.id.replace(/\/.*$/, "")
	return obj
}
function mediaItem(item) {
	return addDerivedFields({
		keywords: item.keywords(),
		name: item.name(),
		description: item.description(),
		favorite: item.favorite(),
		date: Math.floor(item.date().getTime() / 1000),
		id: item.id(),
		height: item.height(),
		width: item.width(),
		filename: item.filename(),
		altitude: item.altitude(),
		size: item.size(),
		location: item.location(),
	})
}
]]
local jxa_lib = jxa_mediaItem
	.. [[

function album(album) {
	return addDerivedFields({
		id: album.id(),
		name: album.name(),
		parent_id: album.parent()?.id(),
		mediaItems: album.mediaItems().map(media_item)
	})
}

function album_shallow(album) {
	return addDerivedFields({
		id: album.id(),
		name: album.name(),
		parent_id: album.parent()?.id(),
		mediaItem_ids: album.mediaItems().map((o) => o.id())
	})
}

// subfolders and albums lists only contain ids
function folder_shallow(folder) {
	return addDerivedFields({
		id: folder.id(),
		name: folder.name(),
		parent_id: folder.parent()?.id(),
		folder_ids: folder.folders().map((o) => o.id()),
		album_ids: folder.albums().map((o) => o.id())
	})
}

// expand folders and albums recursively,but not media items
function folder_structure(folder) {
	return addDerivedFields({
		id: folder.id(),
		name: folder.name(),
		parent_id: folder.parent()?.id(),
		folders: folder.folders().map(folder_structure),
		albums: folder.albums().map(album_shallow)
	})
}

// expand everything, recursively, including media items
function folder(folder) {
	return addDerivedFields({
		id: folder.id(),
		name: folder.name(),
		parent_id: folder.parent()?.id(),
		folders: folder.folders().map(folder),
		albums: folder.albums().map(album)
	})
}

]]

local function objectifyItem(mediaItem)
	mediaItem.getName = function(self)
		return mediaItem.name
			or mediaItem.description
			or mediaItem.keywords and mediaItem.keywords[1]
			or mediaItem.filename:gsub('%.[^.]+$', '')
			or mediaItem.date -- seconds since epoch, shouln'd get this far
	end
	return mediaItem
end

local function mapItemsIfOk(ok, mediaItems, err)
	if not ok then return nil, err end
	return hs.fnutils.map(mediaItems, objectifyItem)
end

local function mapItemIfOk(ok, mediaItem, err)
	if not ok then return nil, err end
	return objectifyItem(mediaItem)
end

--- @return mediaItem[]? mediaItems
--- @return nil, table errors
function M.selected()
	--- @diagnostic disable-next-line: return-type-mismatch
	return mapItemsIfOk(hs.osascript.javascript(string.format(
		[[ %s
	Application("Photos").selection().map(mediaItem); ]],
		jxa_mediaItem
	)))
end
M.selection = M.selected

--- @return mediaItem mediaItem, table error_or_raw_output
--- @return nil, table errors
function M.item(id)
	--- @diagnostic disable-next-line: return-type-mismatch
	return mapItemIfOk(hs.osascript.javascript(string.format(
		[[ %s
const item = Application("Photos").mediaItems.byId("%s");
item ? mediaItem(item) : null; ]],
		jxa_mediaItem,
		id
	)))
end

--- Returns a media item randomly selected from
--- the media items matching the query
---
--- @param query string
--- @return boolean OK, mediaItem mediaItem, table error_or_raw_output
function M.find(query)
	--- @diagnostic disable-next-line: return-type-mismatch
	return mapItemsIfOk(
		hs.osascript.javascript(
			string.format(
				[[ %s
const items=Application("Photos").search({ for: "%s" })
const randomIndex = Math.floor(Math.random() * items.length);
mediaItem(items[randomIndex]); ]],
				jxa_mediaItem,
				string.gsub(query, '"', '\\"')
			)
		)
	)
end

--- Returns a list of media items that match the query
---
--- @param query string
--- @return boolean OK, mediaItem[] mediaItems, table error_or_raw_output
function M.findAll(query)
	--- @diagnostic disable-next-line: return-type-mismatch
	return mapItemsIfOk(
		hs.osascript.javascript(
			string.format(
				[[ %s
Application("Photos").search({ for: "%s" }).map(mediaItem); ]],
				jxa_mediaItem,
				string.gsub(query, '"', '\\"')
			)
		)
	)
end

--- Returns a list of media item ids that match the query
---
--- @param query string
--- @return boolean OK, string[] ids, table error_or_raw_output
function M.findAllIds(query)
	--- @diagnostic disable-next-line: return-type-mismatch
	return hs.osascript.javascript(
		string.format(
			[[
Application("Photos").search({ for: "%s" }).map((o)=>o.id()); ]],
			string.gsub(query, '"', '\\"')
		)
	)
end

return M
