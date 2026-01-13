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


local tempDir -- unnamed until it is created
local function makeTempDir()
	tempDir = string.format('%shammerspoon-photos-server-%s',
		hs.fs.temporaryDirectory(),
		hs.host.globallyUniqueString())
	local success, errorMsg = hs.fs.mkdir(tempDir)
	if not success then tempDir = nil end
	return tempDir
end

local function loadResource(resource)
	return io.open(hs.spoons.resourcePath(resource), 'r'):read'*a'
end

local function info(...)
	hs.printf(...)
end
local function httpError(code, message)
	info('Returning HTTP Error %d: %s', code, hs.inspect(message))
	local e = PS.httpErrors[code] or PS.httpErrors[500]
	return e.errorBody, e.errorCode, {
		['Content-Type'] = 'svg+xml',
		['Content-Length'] = tostring(#e.errorBody),
		['Content-Disposition'] = 'inline; filename=' ..
		    e.filename,
	}
end

local function shQuote(x)
	return '\'' .. string.gsub(x, '\'', "\'\\'\'") .. '\''
end


local function fileResponse(path, filename)
	filename = filename or path:find'[^/]+$'
	local photoBytes, err = io.open(path, 'rb'):read'*a'
	if not photoBytes then return nil, err end
	local size = tostring(#photoBytes)
	if not photoBytes then return nil, err end
	local mime = hs.fs.fileUTIalternate(hs.fs.fileUTI(path),
		'mime')
	if not mime then return nil, err end
	return photoBytes, 200, {
		['Content-Type'] = mime,
		['Content-Length'] = size,
		['Content-Disposition'] = 'inline; filename=' .. filename,
	}
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
	local body, code, headers

	if method ~= 'GET' then return '', 405, {} end
	---@class hs.http
	---@field urlParts fun(path: string): table
	local _ = hs.http.urlParts(path).pathComponents
	local identifier, action = _[2] or '', _[3] or ''

	-- serve static file if one is specified
	if PS.static[identifier] then
		body, code, headers = fileResponse(PS.static[identifier],
			identifier)
		if not body then
			return httpError(500,
				'Unable to load ' .. identifier)
		end
		---@cast headers table
		return body, code, headers
	end

	-- make temporary directory for this request
	if not makeTempDir() then return httpError(500) end

	-- call cli to export photo from Photos App
	local options = '--timeout ' .. PS.timeout
	if (action == 'open') then options = options .. ' --open' end
	local cli = string.format('%s export %s %s %s 2>&1',
		PS.photoCli, options, shQuote(identifier), tempDir
	)
	info('-- photos-cli command:\n%s', cli)
	local photoId, ok = hs.execute(cli)
	info('-- media item found: %s', photoId)
	if not ok then return httpError(500) end
	---@cast photoId string

	-- get first file in temporary directory (there should only be one)
	local filename
	for file in hs.fs.dir(tempDir) do
		if file ~= '.' and file ~= '..' then
			filename = file
			break
		end
	end
	if not filename then
		return httpError(500,
			'No file found in tempdir: ' .. tempDir)
	end
	if not filename then
		return httpError(500,
			'No file found in tempdir: ' .. tempDir)
	end

	-- read file and generate header data
	local filepath = tempDir .. '/' .. filename
	body, code, headers = fileResponse(
		filepath,
		photoId:gsub('%s*$', '') .. filename:match'%..*$'
	)
	if not body then
		return httpError(500,
			'Unable to load file "' .. filepath .. '".')
	end
	---@cast headers table
	local photoBytes = io.open(filepath, 'rb'):read'*a'
	local size = tostring(#photoBytes)
	local mime = hs.fs.fileUTIalternate(hs.fs.fileUTI(filepath),
		'mime')

	-- remove temporary file and directory
	local err
	ok, err = os.remove(filepath)
	if not ok then
		info(
			'Error removing file "%s". %s',
			filepath, err
		)
	end
	ok, err = hs.fs.rmdir(tempDir)
	if not ok then
		info(
			'Error removing temporary directory "%s". %s',
			tempDir, err
		)
	end

	info('-- http response:\n%s',
		hs.inspect(headers))

	-- send the image as an http response
	return body, code, headers
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
			errorCode = 500,
			filename = 'error.svg',
			errorBody = loadResource'error500.svg',
		},
		[404] = {
			errorCode = 404,
			filename = 'missing.svg',
			errorBody = loadResource'error404.svg',
		},
	}
	PS.photoCli = hs.spoons.resourcePath'photos-cli'
	-- static images to serve
	PS.static = {
		['favicon.ico'] = hs.spoons.resourcePath'favicon.ico',
		['apple-touch-icon.png'] = hs.spoons.resourcePath'apple-touch-icon.png',
	}
	-- image to serve when there is no path specified
	PS.static[''] = PS.static['apple-touch-icon.png']
end

function PS:start() return PS.Server and PS.Server:start() end

function PS:stop() return PS.Server and PS.Server:stop() end

return PS
