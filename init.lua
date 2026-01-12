--- === Photos ===
---
--- Control the Photos application, directly or via an http interface
---
---
--- Notes
---  - some returns of MediaItems and Containers are actually just lists of ids.
---  - when do we fetch the details of objects?
---
---

local Photos = {
	name = 'Photos',
	version = '1.0',
	author = 'Erik Ben Heckman <erik@heckman.ca>',
	description = 'Lua interface to the Photos application.',
	homepage = 'https://github.com/Heckman/Photos.spoon',
	license = 'MIT - https://opensource.org/licenses/MIT',
}

Photos.Application = dofile(hs.spoons.resourcePath 'application.lua')

local server -- only load this if we start

---
--- Methods
-----------

function Photos:init() end

function Photos:start()
	server = dofile(hs.spoons.resourcePath 'server.lua')(Photos)
	server.start()
end

function Photos:stop()
	if server then server:stop() end
end

-- function M:bindHotkeys(mapping)
-- local def = { copy_asset_url =  }
-- hs.spoons.bindHotkeysToSpec(def, mapping)
-- end

---
--- utiliy functions
--- -----------------

---@alias PhotosError [string, table]

---@param message string

Photos.Application = dofile(hs.spoons.resourcePath 'application.lua')
Photos.Application.errorHandler = Photos

local metatable = {}

return setmetatable(Photos, metatable)
