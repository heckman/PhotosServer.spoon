type = 'MediaItem'
collection = tonumber

local Mediaitems = {
	commits = {
		id = '',
		keywords = '',
		name = '',
		description = '',
		favorite = '',
		date = ';(function seconds(o){return Array.isArray(o)?o.map(seconds):Math.floor(o.getTime()/1000)}(obj));', -- in seconds since unix epoch
		height = '', -- in pixels
		width = '', -- in pixels
		filename = '', -- no directory information
		altitude = '',
		size = '', -- in bytes
		location = '', -- latitude, longitude
		label = '',
	},
}
MediaItem.subClauses = {
	at, whose, byId, byName
}

local MediaItem = {
	commits = setmetatable({
		properties = ';if(obj.date)obj.date=Math.floor(obj.date.getTime()/1000);obj;',
	}, { __index = Mediaitems.executions }),
}
MediaItem.subClauses = {}

function MediaItem.__index(self, key)
	return MediaItem.methods[key] and MediaItem.methods[key](self)
		or MediaItem.properties[key]
			and self.execute(key, MediaItem.properties[key])
end

function MediaItem:id() self:execute 'id' end
function MediaItem:id() self:execute 'id' end

--[[
if a commiter, then add clause and return exec function to call eith ()
if a singularizer, then add clause and set to single
if a pluralizer,

collection->whose->at->subcollection
collection->whose->subcollection
collection->at->subcollection
collection->byId->subcollection
collection->byName->subcollection
collection->subcollection

type        Application, Folder, Album, MediaItem
folders       nil   foldertype=folder,  state=collection
albums        type=folder,  state=collection
mediaItems
whose
at
byId
byName
properties
<PROPS>
<actions>
