--- === PhotosServer ===
---
--- Serves the Apple Photos Library locally via HTTP
---
---

local PhotosServer = {
	name = 'Photos Server',
	version = '0.2.0',
	author = 'Erik Ben Heckman <erik@heckman.ca>',
	description = 'Serves the Apple Photos library locally via HTTP.',
	homepage = 'https://github.com/Heckman/PhotosServer.spoon',
	license = 'MIT - https://opensource.org/licenses/MIT',
	-- default config:
	host = 'localhost',
	port = 6330,
	bonjour = nil, -- advertised by Bonjour by this name
}

---@class PhotosServer
---@field init fun(): PhotosServer Called automatically by hs.loadSpoon('PhotosServer')
---@field start fun(): PhotosServer Start the HTTP server
---@field stop fun(): PhotosServer Stop the HTTP server
---@field bonjour string the bonjour name of the server. Default: `Photos`
---@field host string the host to serve the HTTP server on. Default: `localhost`
---@field port integer the port to serve the HTTP server on. Default: `6330`

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
---@return boolean success
---@return string found?
---@return string|table error
local function exportMediaItem(identifier, destination)
	---@class hs.osascript
	---@field javascript fun(source: string): boolean, any?, string|table

	identifier = hs.json.encode{ identifier }
	destination = hs.json.encode{ destination }
	local jxa = [[
identifier = ]] .. identifier .. [[[0];
destination = ]] .. destination .. [[[0];
app=Application("Photos");
exportItem=(item)=>{
	app.export(
		[item], {
			to:Path(destination),
			usingOriginals: false
		}
	)
}
try{
	item=app.mediaItems.byId(identifier)
	exportItem(item);
	identifier
} catch {
	item=app.search( {for:identifier} )[0]
	if (item) {
		exportItem(item);
		item.id();
	}
}

]]
	-- print(jxa)
	return hs.osascript.javascript(jxa)
end

-- Return the headers and contents of a media item to be served
--
-- The item needs to be exported to a temporary directory,
-- then loaded by the server to included in an HTTP response.
--
---@param identifier string the uuid of the media item or a search query
---@param destination string the temporary directory to use
---@param basename string the basename to use in the content-disposition header
---@return integer code, table headers, string content
local function loadMediaItem(identifier, destination, basename)
	basename = basename or identifier

	local ok, found, err = exportMediaItem(identifier, destination)
	if not ok then error('JXA error:\n' .. hs.json.encode(err, true)) end
	if found then
		info('-- MediaItem found: ' .. found)
		local path = assert(
			aFileIn(destination),
			'No file found in directory: ' .. destination
		)
		info('-- Mediaitem exported to: ' .. path)
		-- filename = uuid + extension of exported file
		return 200, readFile(path, basename .. path:match'%..*$')
	else
		info('-- MediaItem not found for: ' .. identifier)
		return 404, readFile(PhotosServer.static[404])
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
	if PhotosServer.static[path] then
		local ok, headers, content = pcall(
			readFile, PhotosServer.static[path], path
		)
		if ok then return content, 200, headers end
		info('-- Cannot read static file: ' ..
			PhotosServer.static[path])
		return PhotosServer.serverError()
	end

	-- create a temporary directory to expoer the media item to
	local tempDir = makeTempDir'hammerspoon-photos-server-'
	if not tempDir then
		info'-- Cannot create a temporary directory.'
		return PhotosServer.serverError()
	end

	---@type table
	---@diagnostic disable-next-line: assign-type-mismatch
	local urlParts = hs.http.urlParts(path)
	local uuid = urlParts.pathComponents[2] -- first component is /
	local basename = urlParts.lastPathComponent or ''

	-- load the contents of the media item and its appropriate headers
	-- if no media item is found this will be a 404 response
	local ok, code, headers, content = xpcall(
		loadMediaItem, info,
		-- the Photos App ignores anything that comes after a valid uuid
		-- so we only need to strip of the leading /
		uuid, tempDir, basename
	)

	-- remove the temporary directory and the file within
	-- don't return a server error if the cleanup fails
	xpcall(cleanup, info, tempDir)

	if ok then return content, code, headers end
	return PhotosServer.serverError()
end


---
---
---  PhotosServer Methods
---

-- Initialize the PhotosServer Spoon
--
-- This is called automatically when PhotosServer is loaded by Hammerspoon.
--
---@return PhotosServer
function PhotosServer:init()
	PhotosServer.server = assert(hs.httpserver.new(false, true))
	PhotosServer.server:setCallback(httpHandler)

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
		['Content-Length'] = tostring(#error.content),
	}
	PhotosServer.serverError = function ()
		return error.content, 500, error.header
	end

	-- don't preload the other static responses
	PhotosServer.static = {
		[404] = resourcePath'error404.svg',
		['/favicon.ico'] = resourcePath'favicon.ico',
		['/apple-touch-icon.png'] = resourcePath'apple-touch-icon.png',
	}
	PhotosServer.static['/favicon.png'] = PhotosServer.static
	    ['apple-touch-icon.png']
	PhotosServer.static['/'] = PhotosServer.static[404]

	return self
end

-- Start the HTTP server
--
---@return PhotosServer
function PhotosServer:start()
	if self.bonjour then self.server:setName(self.bonjour) end
	self.server:setInterface(self.host)
	self.server:setPort(self.port)
	info('starting server on ' .. self.host .. ':' .. self.port)
	self.server:start()
	return self
end

-- Stop the HTTP server
--
---@return PhotosServer
function PhotosServer:stop()
	info'stopping server'
	self.server:stop()
	return self
end

return PhotosServer
