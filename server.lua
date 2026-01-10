M = {}

function M.start()
	-- start server
end

function M.strop()
	-- stop server
end

return setmetatable(M, {
	__call = function(self, options)
		for k, v in pairs(options) do
			self[k] = v
		end
		return self
	end,
})



local function markdownLink(mediaItems,base_url)
	local mapped={}
	for i,mediaItem in ipairs(mediaItems) do
		mapped[i]=
	return string.format(
		'[%s](%s%s)',
		alt(mediaItem),
		base_url,
		path('get', mediaItem)
	)
end



function M:base_url()
	local url = self.options.scheme .. '://' .. self.options.host
	if
		self.options.scheme == 'http'
			and self.options.port == 80
		or self.options.scheme == 'https'
			and self.options.port == 443
	then
		return url
	end
	return url .. ':' .. self.options.port
end

function M:markdown_links()
    local ok, ids, err = selected_ids()
    if not ok then
        hs.alert.show(dump(err))
        return
    end
    local links = {}
    for id, name in pairs(ids) do
        table.insert(
            links,
            format_markdown_link(
                name,
                self:base_url() .. id_path(id)
            )
        )
    end
    hs.pasteboard.setContents(
        'public.utf8-plain',
        table.concat(links, '\n')
    )
end

function M.r(fun,...) self[fun](self,...)



--- @param method "get"|"open"|"search"
--- @param param mediaItem|string
local function path(method, param)
	return method == 'get' and '/get/' .. trim_id(param.id)
		or method == 'open' and '/open/' .. trim_id(param.id)
		or method == 'search' and '/search/' .. param
end
