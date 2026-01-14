--- === Photos Server ===
---
--- Access Photos Library via http.
---
---

local PS = {
	name = 'Photos Server',
	version = '0.1.0',
	author = 'Erik Ben Heckman <erik@heckman.ca>',
	description = 'Http interface to the Photos application.',
	homepage = 'https://github.com/Heckman/Photos.spoon',
	license = 'MIT - https://opensource.org/licenses/MIT',
}

PS.name = 'Photos'
PS.host = '127.0.0.3'
PS.port = 6330
PS.timeout = 11 -- seconds to wait for Photos App to respond befroe aborting


local function info(...)
	hs.printf(...)
end

local function resourcePath(resource)
	return hs.spoons.resourcePath('resources/' .. resource)
end
local function loadResource(resource)
	return io.open(resourcePath(resource), 'r'):read'*a'
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
		local ok, err = os.remove(filepath)
		if not ok then
			info(
				'Error removing temporary file "%s". %s',
				filepath, err
			)
		end
	end
	local ok, err = hs.fs.rmdir(dir)
	if not ok then
		info(
			'Error removing temporary directory "%s". %s',
			dir, err
		)
	end
end

---@return string?, function?
local function makeTempDir(basename)
	local dirname = string.format('%s%s%s',
		hs.fs.temporaryDirectory(),
		basename,
		hs.host.globallyUniqueString())
	local ok = hs.fs.mkdir(dirname)
	return ok and dirname or nil
end

---@return string, integer, table
local function serveContent(code, content, filename, mimetype)
	local headers = {
		['Content-Type'] = mimetype,
		['Content-Length'] = tostring(#content),
		['Content-Disposition'] = 'inline; filename=' .. filename,
	}
	info(
		'-- http response %s:\n%s', code, hs.inspect(headers)
	)
	return content, code, headers
end

---@param code integer
---@param tempDir string
---@param messageFormat string
---@vararg any
---@return string, integer, table
local function serveError(code, tempDir, messageFormat, ...)
	messageFormat = messageFormat or 'Unknown error.'
	info('-- ERROR: ' .. messageFormat, ...)
	cleanup(tempDir)
	local e = PS.httpErrors[code] or PS.httpErrors[500]
	if not e.content then return '', code, e.headers end
	return serveContent(code, e.content, e.filename, e.mimetype)
end

---@return string, integer, table
local function serveFile(filepath, filename, tempDir)
	filename = filename or filepath:find'[^/]+$'

	local content = assert(io.open(filepath, 'r'):read'*a',
		{ 500, tempDir, 'Unable to read file "%s".', filepath })

	local mimetype = assert(hs.fs.fileUTIalternate(
			hs.fs.fileUTI(filepath),
			'mime'),
		{ 500, tempDir, 'Unable to get mime type for "%s".',
			filepath }
	)
	cleanup(tempDir)

	return serveContent(200, content, filename, mimetype)
end

local function exportMediaItem(identifier, destination)
	return hs.osascript.javascript(
		string.format(
			[[
Application("Photos").export(
	[Application("Photos").mediaItems.byId("%s")],
	{ to:Path("%s"), usingOriginals:%s }
);]],
			identifier, destination, 'false'
		)
	)
end

---@return string, integer, table
local function httpResponse(method, path, requestHeaders, requestBody)
	info(
		'\n-- http request:\t%s\t%s\n%s\n\n%s',
		method, path, hs.inspect(requestHeaders), requestBody
	)

	assert(method == 'GET', { 405, nil, 'Unsupported HTTP method.' })

	-- the first path component is the leading /
	local identifier = hs.http.urlParts(path).pathComponents[2] or ''

	if PS.static[identifier] then
		return serveFile(PS.static[identifier])
	end

	local tempDir = assert(
		makeTempDir'hammerspoon-photos-server-',
		{ 500, nil, 'Cannot create a temporary directory.' }
	)

	info('-- exporting media item "%s" to "%s"', identifier, tempDir)

	assert(
		exportMediaItem(identifier, tempDir),
		{ 404, tempDir, 'Media item "%s" not found.', identifier }
	)
	local filepath = assert(
		aFileIn(tempDir),
		{ 500, tempDir, 'No file found in tempdir: %s', tempDir }
	)
	info('-- media item exported to "%s"', filepath)

	local filename = identifier .. filepath:match'%..*$'
	info('-- serving media item as "%s".', filename)

	return serveFile(
		filepath, filename, tempDir
	)
end



---@param method 'GET'|'HEAD'|'POST'|'PUT'|'DELETE'|'CONNECT'|'OPTIONS'|'TRACE'|'PATCH'
---@param path string
---@param requestHeaders table
---@param requestBody string
---@return string, integer, table
local function httpHandler(method, path, requestHeaders, requestBody)
	local ok, content, response_code, response_headers =
	    pcall(
		    httpResponse,
		    method, path, requestHeaders, requestBody
	    )
	if ok then
		return content, response_code, response_headers
	else
		---@diagnostic disable-next-line: param-type-mismatch
		return serveError(table.unpack(content))
	end
end

function PS:init()
	---@type HttpServer?
	PS.Server = hs.httpserver.new(false, true)
	if not PS.Server then return nil end
	PS.Server:setName(PS.name)
	PS.Server:setInterface(PS.host)
	PS.Server:setPort(PS.port)
	PS.Server:setCallback(httpHandler)

	-- preloaad error responses, so we don't have to worry about
	-- encountering an error when we're trying to serve an error
	PS.httpErrors = {
		[500] = {
			filename = 'error.svg',
			content = loadResource'error500.svg',
			mimetype = 'svg+xml',
		},
		[404] = {
			filename = 'missing.svg',
			content = loadResource'error404.svg',
			mimetype = 'svg+xml',
		},
		[405] = {
			headers = { Allow = 'GET' },
		},
	}
	-- static images to serve
	PS.static = {
		['favicon.ico'] = resourcePath'favicon.ico',
		['apple-touch-icon.png'] = resourcePath'apple-touch-icon.png',
	}
	PS.static['favicon.png'] = PS.static['apple-touch-icon.png']
	PS.static[''] = PS.static['apple-touch-icon.png']
end

function PS:start() return PS.Server and PS.Server:start() end

function PS:stop() return PS.Server and PS.Server:stop() end

return PS


---@class hs.http
---@field urlParts fun(path: string): table

---@class HttpServer
---@field setName fun(self, name: string)
---@field setInterface fun(self, interface: string)
---@field setPort fun(self, port: number)
---@field setCallback fun(self, callback: function)
---@field start fun(self)
---@field stop fun(self)
