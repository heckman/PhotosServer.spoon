local Application = {}
local App=Application -- shorter alias

---@param jxa string -- javascript to execute
---@return any? -- note that nil may be a successful result
---@overload fun(jxa: string): nil, table -- error always included on failure
local function jxaExec(jxa)
	jxa = 'obj=Application("Photos");' .. jxa
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
	App.errorHandler.alertError(alert)
	print(err)

	return nil, err
end

---
--- Application Static Methods (no self for these functions)
------------------------------------------------------------

---Return the number of elements of a particular class within an object.
---@param specifier any : The objects to be counted.
---@return integer
function App.count(specifier) return 0 end

---Verify that an object exists.
---@param object any
---@return boolean
function App.exists(object) return false end

-- Open a photo library
---@param file File
function App.open(file) end

-- Quit the application.
function App.quit() end

-- Import files into the library
---@param files File[] : The list of files to copy.
---@param into Album? : The album to import into.
---@param skipCheckDuplicates boolean? : Skip duplicate checking and import everything, defaults to false.
---@return MediaItem[]
function App.import(files, into, skipCheckDuplicates) return {} end

-- Export media items to the specified location as files.
---@param items MediaItem[] : The list of media items to export.
---@param to Path : The destination of the export.
---@param usingOriginals boolean] : Export the original files if true, otherwise export rendered jpgs. defaults to false.
function App.export(items, to, usingOriginals) end

---Duplicate an object. Only media items can be duplicated
---@param mediaItem MediaItem : The media item to duplicate
---@return MediaItem : The duplicated media item
function App.duplicate(mediaItem) return App.MediaItem() end

---Create a new object. Only new albums and folders can be created.
---@param type 'Album'|'Folder' type : The class of the new object, allowed values are Album or Folder
---@param named string : The name of the new object.
---@param at Folder : The parent folder for the new object.
---@return Container
function App.make(type, named, at) return App.Album() end

---Delete an object. Only albums and folders can be deleted.
---@param container Container : The album or folder to delete.
function App.delete(container) end

---Add media items to an album.
---@param add MediaItem[] : The list of media items to add.
---@param to Album : The album to add to.
function App.add(mediaItems, to) end

---Display an ad-hoc slide show from a list of media items, an album, or a folder.
---@param mediaItems MediaItemList | Album | Folder : The media items to show.
function App:startSlideshow(mediaItems)
	self:clause('startSlideshow', mediaItems) return self
	App.jxaExec 'Application("Photos").startSlideshow()'
end

--- End the currently-playing slideshow.
function App.stopSlideshow() end

---Skip to next slide in currently-playing slideshow.
function App.nextSlide() end

---Skip to previous slide in currently-playing slideshow.
function App.previousSlide() end

---Pause the currently-playing slideshow.
function App.pauseSlideshow() end

---Resume the currently-playing slideshow.
function App.resumeSlideshow() end

---Show the image at path in the application, used to show spotlight search results\
---@param target string|MediaItem|Container : The full path to the image
function App.spotlight(target) end

---Search for items matching the search string. Identical to entering search text in the Search field in Photos
---@param query string : The text to search for
---@return MediaItem[] : reference(s) to found media item(s)
function App:search(query) self:clause('search', nil) end

---
--- Application properties
--------------------------

local getters = {}
---The name of the application.
---@return string name
function getters.name() return 'Photos' end

---True when the application is active.
---@return boolean
function getters.frontmost() return false end

---The version number of the application.
---@return string
function getters.version() return '0.0.0' end

---The currently selected media items.
---@return MediaItem[]
function getters.selection() return {} end

---Favorited media items.
---@return MediaItem[]
function getters.favoritesAlbum() return {} end

---Returns true if a slideshow is currently running.
---@return boolean
function getters.slideshowRunning() return false end

---The set of recently deleted media items
---@return MediaItem[]
function getters.recentlyDeletedAlbum() return {} end

local Common = {

}
local MediaItem {
	id

}



clause_metatable = {
	app = App,
	exec = jxaExec,
}

local Clause={}
Clause.__tostring = function(c) return string.format('%s(%s)', c[1], c[2]) end

--- Add a clause to the clause chain and update metatable to match
--- @param self
--- @param type
--- @param argument any
function Clause.add(self, type, argument)
	table.insert(self.clauses, setmetatable({ type, argument }, Clause))
	if not argument then return setmetatable(self, type)
	
	if type(argument) == 'number' then
	return argument and self or setmetatable(self, type)
end


local metatable = {
	__index = function(self, key) return getters[key] and getters[key]() end,
	__call = Clause.add({
		clauses = { 'obj=' },
		app = App, -- a reference to the application object
		exec = jxaExec,
	}, 'Application', '"Photos"'),
}

return setmetatable(App, metatable)
