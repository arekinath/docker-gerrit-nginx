local state = ngx.shared.state

function acme_check()
	ngx.timer.at(600, acme_check)
	if state:get('in_check') ~= nil then
		return
	end
	state:set('in_check', true)
	ngx.log(ngx.NOTICE, 'checking ACME cert for validity')
	local ret = os.execute('/usr/bin/openssl x509 -checkend 86400 ' ..
	    '-in /nginx-certs/nginx-cert.pem >/dev/null')
	if ret == 0 then
		state:delete('in_check')
	else
		acme_renew()
	end
end

function acme_renew()
	ngx.log(ngx.WARN, 'attempting to renew ACME cert')
	local ret = os.execute(
	    '/bin/acme_tiny --account-key /nginx-certs/account-key.pem ' ..
	    '--csr /nginx-certs/nginx-csr.pem ' ..
	    '--acme-dir /var/lib/nginx/acme ' ..
	    '> /tmp/nginx-cert.pem.new')
	if ret ~= 0 then
		ngx.log(ngx.ERR,
		    'failed to renew ACME cert, will try again in 5min')
		ngx.timer.at(300, acme_check)
		state:delete('in_check')
		return
	end
	assert(os.execute(
	    'wget -O /tmp/chain.pem ' ..
	    'https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem'
	    ) == 0)
	assert(os.execute('cat /tmp/chain.pem >> /tmp/nginx-cert.pem.new') == 0)
	assert(os.execute('mv /tmp/nginx-cert.pem.new /nginx-certs/nginx-cert.pem') == 0)
	state:delete('in_check')
	assert(os.execute('kill -HUP ' .. master_pid))
end

local gen = require('genupstream')

function regen_ssh_config()
	ngx.timer.at(300, regen_ssh_config)
	ngx.log(ngx.NOTICE, 'checking for ssh upstream changes in DNS')
	gen.regen_resolved(os.getenv('GERRIT_HOST'), os.getenv('SSH_PORT'),
	    '/tmp/upstreams-ssh.conf')
	local ret = os.execute('diff /etc/nginx/upstreams-ssh.conf /tmp/upstreams-ssh.conf >/dev/null')
	if ret ~= 0 then
		ngx.log(ngx.NOTICE, 'ssh upstreams have changed, reloading config')
		assert(os.execute('mv /tmp/upstreams-ssh.conf /etc/nginx/upstreams-ssh.conf') == 0)
		assert(os.execute('kill -HUP ' .. master_pid))
	end
end

assert(ngx.timer.at(2, acme_check))
assert(ngx.timer.at(300, regen_ssh_config))
