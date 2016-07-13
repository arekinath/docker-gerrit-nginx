function lock(name, timeout)
	local state = ngx.shared.state
	local pid = tonumber(ffi.C.getpid())
	if state:get(name) ~= nil then
		return false
	end
	state:set(name, pid, timeout)
	return true
end

function unlock(name)
	local state = ngx.shared.state
	local pid = tonumber(ffi.C.getpid())
	if state:get(name) == pid then
		state:delete(name)
	end
end

function interval(name, func, interval)
	local function timeout(premature)
		if premature then
			return
		end
		assert(ngx.timer.at(interval, timeout))
		if not lock(name, interval * 2) then
			return
		end
		local ok, err = pcall(func)
		unlock(name)
		if not ok then
			ngx.log(ngx.ERR, 'periodic task "' .. name ..
			    '" failed: ' .. err)
		end
	end
	assert(ngx.timer.at(0, timeout))
end

function acme_check()
	ngx.log(ngx.NOTICE, 'checking ACME cert for validity')
	local ret = os.execute('/usr/bin/openssl x509 -checkend 86400 ' ..
	    '-in /nginx-certs/nginx-cert.pem >/dev/null')
	if ret ~= 0 then
		acme_renew()
	end
end

function acme_renew()
	ngx.log(ngx.WARN, 'attempting to renew ACME cert')
	local dir = '/tmp/acme-renew-' .. ffi.C.getpid()
	os.execute('rm -fr ' .. dir)
	assert(os.execute('mkdir -p ' .. dir) == 0)
	local ret = os.execute(
	    '/bin/acme_tiny --account-key /nginx-certs/account-key.pem ' ..
	    '--csr /nginx-certs/nginx-csr.pem ' ..
	    '--acme-dir /var/lib/nginx/acme ' ..
	    '> ' .. dir .. '/cert.pem')
	if ret ~= 0 then
		ngx.log(ngx.ERR,
		    'failed to renew ACME cert, will try again in 5min')
		return
	end
	assert(os.execute(
	    'wget -O ' .. dir .. '/chain.pem ' ..
	    'https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem'
	    ) == 0)
	assert(os.execute('cat ' .. dir .. '/cert.pem ' ..
	    dir .. '/chain.pem > ' .. dir .. '/combined.pem') == 0)
	assert(os.execute('mv ' .. dir .. '/combined.pem ' ..
	    '/nginx-certs/nginx-cert.pem') == 0)
	assert(os.execute('rm -fr ' .. dir) == 0)
	assert(os.execute('kill -HUP ' .. master_pid))
end

local gen = require('genupstream')

function regen_ssh_config()
	local dir = '/tmp/regen-sshconfig-' .. ffi.C.getpid()
	os.execute('rm -fr ' .. dir)
	assert(os.execute('mkdir -p ' .. dir) == 0)
	ngx.log(ngx.NOTICE, 'checking for ssh upstream changes in DNS')
	gen.regen_resolved(os.getenv('GERRIT_HOST'), os.getenv('SSH_PORT'),
	    dir .. '/upstreams-ssh.conf')
	local ret = os.execute('diff /etc/nginx/upstreams-ssh.conf ' ..
	    dir .. '/upstreams-ssh.conf >/dev/null')
	if ret ~= 0 then
		ngx.log(ngx.WARN, 'ssh upstreams have changed, reloading config')
		assert(os.execute('mv ' .. dir .. '/upstreams-ssh.conf /etc/nginx/upstreams-ssh.conf') == 0)
		assert(os.execute('rm -fr ' .. dir) == 0)
		assert(os.execute('kill -HUP ' .. master_pid))
	end
end

interval('acme_check', acme_check, 300)
interval('regen_ssh_config', regen_ssh_config, 300)
