local exports = {}

function exports.regen(host, port, file)
	local f = assert(io.open(file, 'w'))
	f:write('server ' .. host .. ':' .. port .. ' resolve;\n')
	f:close()
end

function exports.regen_resolved(host, port, file)
	local p = io.popen('dig +short +time=2 +edns ' .. host)
	local f = assert(io.open(file, 'w'))
	local didone = false
	while true do
		local line = p:read('*line')
		if line == nil then
			break
		end
		if string.match(line, '^[0-9.]+$') then
			f:write('server ' .. line .. ':' .. port .. ';\n')
			didone = true
		end
	end
	if not didone then
		ngx.log(ngx.WARN, 'no backends found for ' .. host .. ':' .. port)
		f:write('server 127.0.0.1:' .. port .. ';\n')
	end
	f:close()
end

return exports
