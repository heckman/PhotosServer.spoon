--- === PhotosServer ===
---
--- Serves the Apple Photos Library locally via HTTP
---
---
---@class PhotosServer
---@field config PhotosServer.config The HTTP server configuration
---@field init fun(): PhotosServer Called automatically by hs.loadSpoon('PhotosServer')
---@field start fun(config?: PhotosServer.config): PhotosServer Start the HTTP server
---@field stop fun(): PhotosServer Stop the HTTP server

local PS = {
	name = 'Photos Server',
	version = '0.1.0',
	author = 'Erik Ben Heckman <erik@heckman.ca>',
	description = 'Serves the Apple Photos Library locally via HTTP.',
	homepage = 'https://github.com/Heckman/PhotosServer.spoon',
	license = 'MIT - https://opensource.org/licenses/MIT',
}

---@class PhotosServer.config
---@field name string the bonjour name of the server. Default: `Photos`
---@field host string the host to serve the HTTP server on. Default: `localhost`
---@field port integer the port to serve the HTTP server on. Default: `6330`
---@field origin string? the origin of the Photos App. Default: `http://localhost:6330`
---this can be different from the host:port settings--it is where photos should
---be expected to be found. For instance, I use `http://photos.local`.

-- dont try and set these directly, instead
-- use the :configure or :start methods to do so
-- this is because the origin field is stored elsewhere.
---@type PhotosServer.config
PS.config = {
	name = 'Photos Server',
	host = 'localhost',
	port = 6330,
}

---
---
---  Public function (AKA static methods)
---
---  These are all defined in the photosApplication table,
---  which will soon be moved to its own spoon
PS.photosApplication = dofile(
	hs.spoons.resourcePath'photosApplication.lua'
)
PS.photosApplication.origin = 'http://localhost:6330'
PS.photosSelection = PS.photosApplication.selection
PS.copySelectionAsMarkdown = PS.photosApplication
    .copySelectionAsMarkdown


--   Method definitions are at the end of the file,
--   so that they can call the local functions.

---
---
--=  Local functions
---

local function info(message)
	print(message)
	return message
end

local function aFileIn(dir)
	for file in hs.fs.dir(dir) do
		if file ~= '.' and file ~= '..' then
			return dir .. '/' .. file
		end
	end
	return nil
end
local function cleanup(dir)
	if not dir then return end
	local filepath = aFileIn(dir)
	if filepath then
		assert(
			os.remove(filepath),
			'Error removing file "' .. filepath .. '".'
		)
	end
	assert(
		hs.fs.rmdir(dir),
		'Error removing temporary directory: ' .. dir
	)
end

-- Create a temporary directory
--
-- The directory is created within the user's temporary directory with
-- the provided base name appended with a very long random string.
--
---@param basename string
---@return string | nil directory the parh of the new directory, if successful
local function makeTempDir(basename)
	local dirname = string.format('%s%s%s',
		hs.fs.temporaryDirectory(),
		basename,
		hs.host.globallyUniqueString())
	local ok = hs.fs.mkdir(dirname)
	return ok and dirname or nil
end

-- Return the response headers and contents of a file to serve
--
---@param filepath string the absolute path to the file.
---@param filename? string serve the file with this filename in its content-disposition field; defaults to the last part of the path.
---@return table headers, string body the response headers and file contents.
---@fallible when the file can't be read or its mimetype can't be determined
local function readFile(filepath, filename)
	---@cast filename string
	filename = filename or filepath:find'[^/]+$'

	local file_contents = assert(
		io.open(filepath, 'r'):read'*a',
		'Unable to read file "' .. filepath .. '".'
	)

	local file_mimetype = assert(
		hs.fs.fileUTIalternate(hs.fs.fileUTI(filepath), 'mime'),
		'Unable to get mime type for "..filepath..".'
	)

	return {
		['Content-Type'] = file_mimetype,
		['Content-Length'] = tostring(#file_contents),
		['Content-Disposition'] = 'inline; filename=' .. filename,
	}, file_contents
end

-- Export a media item from the Photos App
--
---@param identifier string the uuid of the media item
---@param destination string the directory to export the file to
---@return boolean successful
local function exportMediaItem(identifier, destination)
	---@class hs.osascript
	---@field javascript fun(source: string): boolean, any?, string|table

	return ( -- only return the first value
		hs.osascript.javascript(
			string.format(
				[[
Application("Photos").export(
	[Application("Photos").mediaItems.byId("%s")],
	{ to:Path("%s"), usingOriginals:%s }
);]],
				identifier, destination, 'false'
			)
		)
	)
end

-- Return the headers and contents of a media item to be served
--
-- The item needs to be exported to a temporary directory,
-- then loaded by the server to included in an HTTP response.
--
---@param uuid string the uuid of the media item
---@param destination string the temporary directory to use
---@return integer code, table headers, string content
local function loadMediaItem(uuid, destination)
	if exportMediaItem(uuid, destination) then
		local path = assert(
			aFileIn(destination),
			'No file found in directory: ' .. destination
		)
		info('-- Mediaedia item exported to: ' .. path)
		-- filename = uuid + extension of exported file
		return 200, readFile(path, uuid .. path:match'%..*$')
	else
		info('-- Media item not found for: ' .. uuid)
		return 404, readFile(PS.static[404])
	end
end

-- Handle an http request
--
-- See: https://www.hammerspoon.org/docs/hs.httpserver.html
--
---@param method 'GET'|'HEAD'|'POST'|'PUT'|'DELETE'|'CONNECT'|'OPTIONS'|'TRACE'|'PATCH'
---@param path string
---@param requestHeaders table
---@param requestBody string
---@return string, integer, table
local function httpHandler(method, path, requestHeaders, requestBody)
	info('\n-- http request:' .. method .. '\t"' .. path .. '"')

	-- we only accept GET requests
	if method ~= 'GET' then
		info'-- Unsupported HTTP method.'
		return '', 405, { Allow = 'GET' }
	end

	-- if the path is a static file then serve it
	if PS.static[path] then
		local ok, headers, content = pcall(
			readFile, PS.static[path], path
		)
		if ok then return content, 200, headers end
		info('-- Cannot read static file: ' .. PS.static[path])
		return PS.serverError()
	end

	-- create a temporary directory to expoer the media item to
	local tempDir = makeTempDir'hammerspoon-photos-server-'
	if not tempDir then
		info'-- Cannot create a temporary directory.'
		return PS.serverError()
	end

	-- load the contents of the media item and its appropriate headers
	-- if no media item is found this will be a 404 response
	local ok, code, headers, content = xpcall(
		loadMediaItem, info,
		-- the Photos App ignores anything that comes after a valid uuid
		-- so we only need to strip of the leading /
		path:sub(2), tempDir
	)

	-- remove the temporary directory and the file within
	-- don't return a server error if the cleanup fails
	xpcall(cleanup, info, tempDir)

	if ok then return content, code, headers end
	return PS.serverError()
end

---
---
---  PhotoServer Methods
---

-- Initialize the PhotosServer Spoon
--
-- This is called automatically when PhotosServer is loaded by Hammerspoon.
--
---@return PhotosServer
function PS:init()
	PS.server = assert(hs.httpserver.new(false, true))
	PS.server:setCallback(httpHandler)
	local resourcePath = function (resource)
		return assert(
			hs.spoons.resourcePath('resources/' .. resource),
			'Unable to find resource: ' .. resource
		)
	end
	local loadResource = function (resource)
		return assert(
			io.open(resourcePath(resource), 'r'):read'*a',
			'Unable to read resource: ' .. resource
		)
	end
	-- preloaad content for http 500 server error response,
	-- to avoid encountering possible errors when serving it.
	local error = { content = loadResource'error500.svg' }
	error.header = {
		['Content-Type'] = 'svg+xml',
		['Content-Length'] = #error.content,
	}
	PS.serverError = function ()
		return error.content, 500, error.header
	end

	-- don't preload the other static responses
	PS.static = {
		[404] = resourcePath'error404.svg',
		['/favicon.ico'] = resourcePath'favicon.ico',
		['/apple-touch-icon.png'] = resourcePath'apple-touch-icon.png',
	}
	PS.static['/favicon.png'] = PS.static['apple-touch-icon.png']
	PS.static['/'] = PS.static['apple-touch-icon.png']

	return self
end

-- Start the HTTP server
--
-- If a config object is provided, settings will be changed before starting.
-- Each valid setting within will be saved in the PhotosServer configuration.
-- Settings absent from the provided config object will remain unchanged.
--
-- For example, PhotosServer.start{ host = '127.0.0.3' } will permanently
-- alter the host setting and will leave the name and port settings intact.
--
---@param config? PhotosServer.config
---@return PhotosServer
function PS:start(config)
	self:configure(config)
	self.server:setName(self.config.name)
	self.server:setInterface(self.config.host)
	self.server:setPort(self.config.port)
	info('starting server on ' ..
		self.config.host .. ':' .. self.config.port)
	self.server:start()
	return self
end

-- Stop the HTTP server
--
-- Settings in PhotosServer.config will be maintained after stopping.
--
---@return PhotosServer
function PS:stop()
	info'stopping server'
	self.server:stop()
	return self
end

-- If a config object is provided, each valid setting will be saved in the
-- PhotosServer configuration. Settings absent from the provided config object
-- will remain unchanged.
--
-- For example, PhotosServer.configure{ host = '127.0.0.3' }
-- will leave the name and port settings intact.
--
---@param config? PhotosServer.config
function PS:configure(config)
	if config then
		if config.name then self.config.name = config.name end
		if config.host then self.config.host = config.host end
		if config.port then self.config.port = config.port end
		if config.origin then
			self.photosApplication.origin = config.origin
		end
	end
	return self
end

-- This method will be removed
-- when photosApplication is moved to its own spoon
---@param mapping table
---@return PhotosServer
function PS:bindHotkeys(mapping)
	local spec = {
		copyMarkdown = PS.photosApplication
		    .copySelectionAsMarkdown,
	}
	hs.spoons.bindHotkeysToSpec(spec, mapping)
	return self
end

return PS
