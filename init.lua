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


---@return string?, string?
local function makeTempDir(basename)
	local dirname = string.format('%s%s%s',
		hs.fs.temporaryDirectory(),
		basename,
		hs.host.globallyUniqueString())
	local ok, err = hs.fs.mkdir(dirname)
	if ok then return dirname end
	return nil, err
end
local function aFileIn(dir)
	for file in hs.fs.dir(dir) do
		if file ~= '.' and file ~= '..' then
			return dir .. '/' .. file
		end
	end
	return nil
end
local function loadResource(resource)
	return io.open(hs.spoons.resourcePath(resource), 'r'):read'*a'
end

local function info(...)
	hs.printf(...)
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

---@return string, integer, table
local function serveContent(code, content, filename, mimetype)
	local headers = {
		['Content-Type'] = mimetype,
		['Content-Length'] = tostring(#content),
		['Content-Disposition'] = 'inline; filename=' .. filename,
	}
	cleanup()
	info(
		'-- http response %s:\n%s', code, hs.inspect(headers)
	)
	return content, code, headers
end

---@return string, integer, table
local function serveError(code)
	local e = PS.httpErrors[code] or PS.httpErrors[500]
	if not e.content then return '', code, e.headers end
	return serveContent(code, e.content, e.filename, e.mimetype)
end

---@return string, integer, table
local function serveFile(filepath, filename, tempDir)
	filename = filename or filepath:find'[^/]+$'

	local content, err = io.open(filepath, 'r'):read'*a'
	if not content then
		info(
			'Unable to read file "%s".',
			filepath
		)
		cleanup(tempDir)
		return serveError(500)
	end

	local mimetype = hs.fs.fileUTIalternate(
		hs.fs.fileUTI(filepath),
		'mime'
	)
	if not mimetype then
		info(
			'Unable to get mime type for "%s".',
			filepath
		)
		cleanup(tempDir)
		return serveError(500)
	end

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



---@param method 'GET'|'HEAD'|'POST'|'PUT'|'DELETE'|'CONNECT'|'OPTIONS'|'TRACE'|'PATCH'
---@param path string
---@param requestHeaders table
---@param requestBody string
---@return string, integer, table
local function httpResponse(method, path, requestHeaders, requestBody)
	info('\n-- http request:\t%s\t%s\n%s\n\n%s',
		method, path, hs.inspect(requestHeaders), requestBody
	)
	if method ~= 'GET' then return '', 405, {} end

	---@class hs.http
	---@field urlParts fun(path: string): table

	-- the first path component is the leading /
	local identifier = hs.http.urlParts(path).pathComponents[2] or ''
	-- serve static file if one is specified
	if PS.static[identifier] then
		return serveFile(PS.static[identifier])
	end

	-- make temporary directory for this request
	local tempDir = makeTempDir'hammerspoon-photos-server-'
	if not tempDir then
		info'Cannot create a temporary directory.'
		return serveError(500)
	end

	info(
		'-- exporting media item "%s" to "%s"',
		identifier, tempDir
	)

	local ok = exportMediaItem(identifier, tempDir)
	if not ok then
		info(
			'Unable to export mediaItem(%s) to "%s".',
			identifier, tempDir
		)
		cleanup(tempDir)
		return serveError(404)
	end

	-- get first file in temporary directory (there should only be one)
	local filepath = aFileIn(tempDir)
	if not filepath then
		info(
			'No file found in tempdir: %s',
			PS.tempDir
		)
		cleanup(tempDir)
		return serveError(500)
	end
	---@cast filepath string


	-- read file and generate header data

	return serveFile(filepath, identifier .. filepath:match'%..*$',
		tempDir)
end

---@class HttpServer
---@field setName fun(self, name: string)
---@field setInterface fun(self, interface: string)
---@field setPort fun(self, port: number)
---@field setCallback fun(self, callback: function)
---@field start fun(self)
---@field stop fun(self)
function PS:init()
	---@type HttpServer?
	PS.Server = hs.httpserver.new(false, true)
	if not PS.Server then return nil end
	PS.Server:setName(PS.name)
	PS.Server:setInterface(PS.host)
	PS.Server:setPort(PS.port)
	PS.Server:setCallback(httpResponse)
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
		['favicon.ico'] = hs.spoons.resourcePath'favicon.ico',
		['apple-touch-icon.png'] = hs.spoons.resourcePath'apple-touch-icon.png',
	}
	PS.static['favicon.png'] = PS.static['apple-touch-icon.png']
	PS.static[''] = PS.static['apple-touch-icon.png']
end

function PS:start() return PS.Server and PS.Server:start() end

function PS:stop() return PS.Server and PS.Server:stop() end

return PS
