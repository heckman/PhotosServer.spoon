ObjSpec = {}

function ObjSpec:init()
	--	ObjSpec.jxaExec = hs.loadSpoon 'jxa'.exec() or
	--	    error 'jxa.spoon not found'
	ObjSpec.jxaExec = dofile(hs.spoons.resourcePath 'jxa')
end

function ObjSpec:__call(...)
	local obj = self.__class
	if obj.__call then return obj.__call(self, ...) end
	if type(obj) == 'string' then
		self.arguments = { ... }
		return ObjSpec.jxaExec(('obj=' .. self .. obj))
	end
end

function ObjSpec:__tostring()
	return self.argument
	    and string.format('%s(%s)', self._clause,
		    table.concat(self.arguments, ', '))
	    or string.format('%s', self._clause)
end

function ObjSpec:__concat()
	return self.__parent and self.__parent .. '.' .. tostring(self)
	    or tostring(self)
end

function ObjSpec:__index(key)
	if self.__class[key] then
		return setmetatable(
			{
				__clause = key,
				__class = self.__class[key],
				__parent = self
			}, ObjSpec)
	end
	error(string.format('Unknown key: %s\nObejectSpecifier: %s',
		hs.inspect(self)))
end -- retuend

return setmetatable(ObjSpec, {
	__call = function (self, jxaExec)
		self.jxaExec = jxaExec
		return self
	end,
})
