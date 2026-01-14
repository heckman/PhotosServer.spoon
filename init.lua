--- === PhotosServer ===
---
--- Access Photos Library via http.
---
---

local PS = {
	name = 'Photos Server',
	version = '0.1.0',
	author = 'Erik Ben Heckman <erik@heckman.ca>',
	description = 'Http interface to the Apple Photos Library.',
	homepage = 'https://github.com/Heckman/PhotosServer.spoon',
	license = 'MIT - https://opensource.org/licenses/MIT',
}

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

-- Create a directory within the user's temporary directory with
-- the provided basename appended with a very long random string.
--
---@param basename string
---@return string | nil  directory-name or nil if unsuccesssful
local function makeTempDir(basename)
	local dirname = string.format('%s%s%s',
		hs.fs.temporaryDirectory(),
		basename,
		hs.host.globallyUniqueString())
	local ok = hs.fs.mkdir(dirname)
	return ok and dirname or nil
end

-- Read a file and return its contents and appropriate response headers
--
---@param filepath string the absolute path to the file.
---@param filename? string serve the file with this filename in its content-disposition field; defaults to the last part of the path.
---@return table headers, string body the response headers and file contents.
---@fallible
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

-- Export a media item from the Photos App to the specified directory.
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

-- Load the specified media item and return its contents
-- along with the appropriate response headers.
--
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

-- Handle http requests
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

---@alias PhotosServer.config { name: string, host: string, port: integer }
---@class PhotosServer
---@field config PhotosServer.config
---@field init fun(): PhotosServer
---@field start fun(config?: PhotosServer.config): PhotosServer
---@field stop fun(): PhotosServer

--- PhotosServer:config(config)
--- Variable
--- The HTTP server configuration table
---
--- Fields:
---  * name - The bonjour name of the server. Default: `Photos`
---  * host - The host to serve the HTTP server on. Default: `localhost`
---  * port - The port to serve the HTTP server on. Default: `6330`
---
--- Returns:
---  * The PhotosServer spoon
---
PS.config = {
	name = 'Photos Server',
	host = 'localhost',
	port = 6330,
}
function PS:init()
	PS.Server = assert(hs.httpserver.new(false, true))
	PS.Server:setCallback(httpHandler)
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

--- PhotosServer:start([config])
--- Method
--- Starts the HTTP server.
---
--- Parameters:
---  * config - optional [configuration table](#config). If thie is set, then
---             PhotosServer:config will be set before starting the server.
---
--- Returns:
---  * The PhotosServer spoon.
---
function PS:start(config)
	self:config(config)
	PS.Server:setName(self.config.name)
	PS.Server:setInterface(self.config.host)
	PS.Server:setPort(self.config.port)
	PS.Server:start()
	return self
end

--- PhotosServer:stop()
--- Method
--- Stops the HTTP server.
---
--- Returns:
---  * The PhotosServer spoon.
---
function PS:stop()
	PS.Server:stop()
	return self
end

---@param config? { name: string, host: string, port: integer }
function PS:config(config)
	if config then
		if config.name then self.name = config.name end
		if config.host then self.host = config.host end
		if config.port then self.port = config.port end
	end
	return self
end

return PS
