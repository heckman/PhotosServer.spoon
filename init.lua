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




---@class HttpServer
---@field setName fun(self, name: string)
---@field setInterface fun(self, interface: string)
---@field setPort fun(self, port: number)
---@field setCallback fun(self, callback: function)
---@field start fun(self)
---@field stop fun(self)
---@type HttpServer
local Server = hs.httpserver.new(false, true) or {}


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

local function httpError(code, message)
	print(string.format('Error %d: %s', code, hs.inspect(message)))
	local e = PS.httpErrors[code] or PS.httpErrors[500]
	return e.errorBody, e.errorCode, {
		['Content-Type'] = 'svg+xml',
		['Content-Length'] = tostring(#e.errorBody),
		['Content-Disposition'] = 'inline; filename=' ..
		    e.filename,
	}
end


local function callPhotosLegacyCli(command, arguments, options)
	local jax = string.format([[
command=commands.%s;
command.do(%s,{ ...command.options, timeout: 12, ...%s });
]],
		command,
		string.gsub(hs.json.encode(arguments), '\\/',
			'/'), hs.inspect(options):gsub('=', ':'))
	-- print(hs.inspect(command))
	-- print(hs.inspect(arguments), hs.json.encode(arguments))
	-- print(hs.inspect(options), hs.json.encode(options))
	print(jax)
	return hs.osascript.javascript(PS.PhotosLegacyCli .. jax)
end

local function shQuote(x)
	return '\'' .. string.gsub(x, '\'', "\'\\'\'") .. '\''
end

---@param method 'GET'|'HEAD'|'POST'|'PUT'|'DELETE'|'CONNECT'|'OPTIONS'|'TRACE'|'PATCH'
---@param path string
---@param requestHeaders table
---@param requestBody string
---@return string, integer, table
local function httpResponse(method, path, requestHeaders, requestBody)
	if method ~= 'GET' then return '', 405, {} end
	local _ = hs.http.urlParts(path).pathComponents
	local identifier, action = _[2] or '', _[3] or ''
	print('request for: ' .. identifier .. ' / ' .. action)

	if string.find(identifier, '^favicon') or
	string.find(identifier, '^%s*$') then
		return httpError(404)
	end

	if not makeTempDir() then return httpError(500) end
	print('tempDir:', tempDir)

	local options = '--timeout 11'
	if (action == 'open') then options = options .. ' --open' end

	local cli = string.format(
		'photos-cli export %s %s %s 2>&1',
		options, shQuote(identifier), tempDir
	)
	print(cli)
	local out, ok = hs.execute(cli)

	-- local ok, out, err = callPhotosLegacyCli('export',
	-- 	{ identifier, tempDir },
	-- 	{ open = (action == 'open') })

	D{ ok, out }
	-- if true then return httpError(500, 'debug stop') end

	if not ok then return httpError(500, cli .. '\n>> ' .. out) end


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

	local filepath = tempDir .. '/' .. filename
	local mime = hs.fs.fileUTIalternate(hs.fs.fileUTI(filepath),
		'mime')

	local photoBytes = io.open(filepath, 'rb'):read'*a'

	-- if not os.remove(filepath) then print(err) end
	-- if not hs.fs.rmdir(tempDir) then print(err) end

	return photoBytes, 200, {
		['Content-Type'] = mime,
		['Content-Length'] = tostring(#photoBytes),
		['Content-Disposition'] = 'inline; filename=' .. filename,
	}
end

function PS:init()
	Server:setName'Photos'
	Server:setInterface'127.0.0.3'
	Server:setPort(6331)
	Server:setCallback(httpResponse)
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

	PS.PhotosLegacyCli = loadResource'photos-cli'
end

function PS:start() return Server and Server:start() end

function PS:stop() return Server and Server:stop() end

return PS
