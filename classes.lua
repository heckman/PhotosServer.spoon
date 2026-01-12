Class = {}

local class_metatable = {
	__index = {
		extends = function (self, ...)
			for k, v in pairs { ... } do
				if not self[k] then self[k] = v end
			end
			return self
		end,
	},
}
local function class(t, ...)
	for k, v in pairs { ... } do
		if not t[k] then t[k] = v end
	end
	return t
end

local identifier = {
	__call = function (self, argument)
		self.argument = argument
		self.class = string.sub(self.parent.class, 1, -2)
		return self
	end,
}
local filter = {
	__call = function (self, argument)
		self.argument = argument
		self.class = self.parent.class
		return self
	end,
}
local collection = {
	at = identifier,
	byId = identifier,
	byName = identifier,
	whose = filter,
}

local container = {
	id = '',
	name = '',
	parent = '',
}

local folder = class {
	folders = Class.folders,
	albums = Class.albums,
}:extends(container)

Class.folder = class { spotlight = '' }:extends(folder)
Class.folders = class(folder):extends(collection)

local album = class {
	mediaItems = Class.mediaItems,
}:extends(container)

Class.album = class { spotlight = '' }:extends(album)
Class.albums = class(album):extends(album, collection)

local mediaItem = {
	id = '',
	keywords = '',
	name = '',
	description = '',
	favorite = '',
	date = [[;
(function seconds(o){return Array.isArray(o)?o.map(seconds):Math.floor(o.getTime()/1000)}(obj));
]],
	height = '',
	width = '',
	filename = '',
	altitude = '',
	size = '',
	location = '',
}

Class.mediaItem = class {
	spotlight = '',
	properties = [[;
if(obj.date)obj.date=Math.floor(obj.date.getTime()/1000);obj;
]],
}:extends(
	mediaItem
)

Class.mediaItems = class(mediaItem):extends(collection)




Class.application = {}

Class.application.search = {
	__call = function (self, argument)
		self.argument = argument
		self.class = Class.mediaItems
		return self
	end,
}
