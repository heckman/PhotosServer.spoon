local Application = {}
---
--- Application Static Methods (no self for these functions)
------------------------------------------------------------

---Return the number of elements of a particular class within an object.
---@param specifier any : The objects to be counted.
---@return integer
function Application.count(specifier) return 0 end

---Verify that an object exists.
---@param object any
---@return boolean
function Application.exists(object) return false end

-- Open a photo library
---@param file File
function Application.open(file) end

-- Quit the application.
function Application.quit() end

-- Import files into the library
---@param files File[] : The list of files to copy.
---@param into Album? : The album to import into.
---@param skipCheckDuplicates boolean? : Skip duplicate checking and import everything, defaults to false.
---@return MediaItem[]
function Application.import(files, into, skipCheckDuplicates) return {} end

-- Export media items to the specified location as files.
---@param items MediaItem[] : The list of media items to export.
---@param to Path : The destination of the export.
---@param usingOriginals boolean] : Export the original files if true, otherwise export rendered jpgs. defaults to false.
function Application.export(items, to, usingOriginals) end

---Duplicate an object. Only media items can be duplicated
---@param mediaItem MediaItem : The media item to duplicate
---@return MediaItem : The duplicated media item
function Application.duplicate(mediaItem) return Application.MediaItem() end

---Create a new object. Only new albums and folders can be created.
---@param type 'Album'|'Folder' type : The class of the new object, allowed values are Album or Folder
---@param named string : The name of the new object.
---@param at Folder : The parent folder for the new object.
---@return Container
function Application.make(type, named, at) return Application.Album() end

---Delete an object. Only albums and folders can be deleted.
---@param container Container : The album or folder to delete.
function Application.delete(container) end

---Add media items to an album.
---@param add MediaItem[] : The list of media items to add.
---@param to Album : The album to add to.
function Application.add(mediaItems, to) end


---Display an ad-hoc slide show from a list of media items, an album, or a folder.
---@param mediaItems MediaItemList | Album | Folder : The media items to show.
function Application.startSlideshow(mediaItems)
	Application.jxaExec 'Application("Photos").startSlideshow()'
end

--- End the currently-playing slideshow.
function Application.stopSlideshow() end

---Skip to next slide in currently-playing slideshow.
function Application.nextSlide() end

---Skip to previous slide in currently-playing slideshow.
function Application.previousSlide() end

---Pause the currently-playing slideshow.
function Application.pauseSlideshow() end

---Resume the currently-playing slideshow.
function Application.resumeSlideshow() end

---Show the image at path in the application, used to show spotlight search results\
---@param target string|MediaItem|Container : The full path to the image
function Application.spotlight(target) end

---Search for items matching the search string. Identical to entering search text in the Search field in Photos
---@param query string : The text to search for
---@return MediaItem[] : reference(s) to found media item(s)
function Application.search(query) return {} end

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

return setmetatable(Application, {
	__index = function(self, key) return getters[key] and getters[key]() end,
	__call = function(self, spoon)
		self.Photos = spoon
		self.jxaExec = spoon.jxaExec
		return self
	end,
})
