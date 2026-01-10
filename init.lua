--- === Photos ===
---
--- Control the Photos application, directly or via an http interface
---
---
---
---
---

local Photos = {
	name = 'Photos',
	version = '1.0',
	author = 'Erik Ben Heckman <erik@heckman.ca>',
	homepage = 'https://github.com/Heckman/Photos.spoon',
	license = 'MIT - https://opensource.org/licenses/MIT',

	-- defaut options, override by calling:
	--   Photos{options} or Photos.
	-- or when creating the Spoon: hs.loadSpoon 'Photos' {options}
	-- (I think this will work but haven't tried it yet))
	options = {
		scheme = 'http',
		host = 'photos.local',
		port = 80,
	},
}
-- load the classes locally
dofile(hs.spoons.resourcePath 'common.lua')
local MediaItem = dofile(hs.spoons.resourcePath 'LazyMediaItem.lua')
-- local Album = dofile(hs.spoons.resourcePath 'Album.lua')
-- local Folder = dofile(hs.spoons.resourcePath 'Folder.lua')
-- also expose them publically
Photos.MediaItem = MediaItem
-- Photos.Album = Album
-- Photos.Folder = Folder

-- for submodule in { "server" } do
-- 	_ENV[submodule] = dofile(hs.spoons.resourcePath(submodule..'.lua'))
-- end

function Photos:start()
	self.server = dofile(hs.spoons.resourcePath 'server.lua')(M.options)
	self.server.start(self)
end

function Photos:stop()
	if self.server then self.server.stop() end
end

function Photos:error_alert(err)
	--hs.alert.show(hs.inspect { err, self })
	error(hs.inspect { err, self }, 2)
end

-- function M:bindHotkeys(mapping)
-- local def = { copy_asset_url =  }
-- hs.spoons.bindHotkeysToSpec(def, mapping)
-- end

return setmetatable(Photos, {
	__call = function(self, options)
		for k, v in pairs(options) do
			self.options[k] = v
		end
		return self
	end,
})
