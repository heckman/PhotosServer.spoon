Objects = {}


Objects.clause

---@class MediaItem
---@field pcls 'MediaItem'
---@field id string
---@field keywords string[] | nil
---@field name string? -- AKA the title
---@field description string?
---@field favorite boolean?
---@field date number? -- in seconds since unix epoch
---@field height number? -- in pixels
---@field width number? -- in pixels
---@field filename string -- no directory information
---@field altitude number?
---@field size number? -- in bytes
---@field location [ number, number ]? -- latitude, longitude
---@field label string

---@class Album
---@field pcls 'Album'
---@field id string
---@field parent Folder
---@field mediaItems MediaItem[]

---@class Folder
---@field pcls 'Folder'
---@field id string
---@field parent Folder
---@field albums Album[]
---@field folders Folder[]

---@alias Container Album|Folder
---@alias MediaItemList table -- has methods in metatable

---@alias File string -- for future expansion
---@alias Path string -- for future expansion

---@alias PhotosObject MediaItem|Album|Folder
---@alias PhotosObjectType 'MediaItem'|'Album'|'Folder'

Objects._jxa = {}
Objects._jxa.typeById = function(self)
	return string.format('%s.byId("%s")', self.type, self.id)
end
Objects._jxa.containerMediaItems = function(self)
	return string.format('%s.byId("%s").mediaItems()', self.type, self.id)
end
Objects._jxa.mediaItemListMediaItems = function(self)
	return string.format(
		'mediaItems.whose({id:{_in:%s}})',
		hs.json.encode(self)
	)
end

Objects._method = {}

function Objects._method.duplicate(mediaItem) end
function Objects._method.mediaItemWhere(mediaItemList) end
Objects._class = {
	mediaItem = { mt = {} },
	album = { mt = {} },
	folder = { mt = {} },
	mediaItemList = { mt = {} },
	objectCreationError = { mt = {} },
}

Objects._class.mediaItemList.mt.__index = {
	_type = 'MediaItemList',
	byId = Objects._method.mediaItembyId,
	where = Objects._method.mediaItemWhere,
	_jxa = {
		mediaItems = function(self)
			return string.format(
				'mediaItems.whose({id:{_in:%s}})',
				hs.json.encode(self)
			)
		end,
	},
}
Objects._class.mediaItem.init = function(obj)
	obj.label = obj.name
		or obj.description
		or obj.keywords and obj.keywords[1]
		or obj.filename and obj.filename:gsub('%.[^.]+$', '')
	return obj
end
Objects._class.mediaItem.mt.__index = {
	_type = 'MediaItem',
	spotlight = Objects._method.spotlight,
	duplicate = Objects._method.duplicate,
	_jxa = { self = Objects._jxa.typeById },
}

Objects._class.album.init = function(obj)
	setmetatable(obj.mediaItems, Objects._class.mediaItemList.mt)
	return obj
end
Objects._class.album.mt.__index = {
	_type = 'Album',
	spotlight = Objects._method.spotlight,
	_jxa = {
		self = Objects._jxa.typeById,
		mediaItems = Objects._jxa.containerMediaItems,
	},
}
Objects._class.folder.init = function(obj)
	setmetatable(obj.mediaItems, Objects._class.mediaItemList.mt)
	return obj
end
Objects._class.folder.mt.__index = {
	_type = 'Folder',
	spotlight = Objects._method.spotlight,
	_jxa = {
		self = Objects._jxa.typeById,
		mediaItems = Objects._jxa.containerMediaItems,
	},
}

---
--- Public Functions
---------------------------------------------

---@param id string
---@return MediaItem | nil, PhotosError
---@diagnostic disable-next-line: return-type-mismatch
function Objects.mediaItem(id) return Objects.new('mediaItem', id) end

---@param id string
---@return Album | nil, PhotosError
---@diagnostic disable-next-line: return-type-mismatch
function Objects.album(id) return Objects.new('album', id) end

---@param id string
---@return Folder | nil, PhotosError
---@diagnostic disable-next-line: return-type-mismatch
function Objects.folder(id) return Objects.new('folder', id) end

function Objects.new(type, id)
	local class = Objects._class[type]
	local obj, err =
		Objects.jxaExec(Objects._jxa.typeById { type = type, id = id })
	if err then
		return nil, err
	else
		---@cast obj MediaItem|Album|Folder
		obj.bid = obj.id and obj.id:gsub('/.*$', '')
		return setmetatable(class.init(obj), class.mt)
	end
end

return setmetatable(Objects, {
	__call = function(self, spoon)
		self.Photos = spoon
		self.jxaExec = spoon.jxaExec
		self.jxaError = spoon.jxaError
		self.spotlight = spoon.Application.spotlight
		return self
	end,
})
