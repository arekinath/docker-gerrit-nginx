ffi = require('ffi')
ffi.cdef([[
int getpid(void);
int access(const char *path, int amode);
]])
master_pid = tonumber(ffi.C.getpid())
F_OK = 0
R_OK = 4
W_OK = 2
X_OK = 1

ngx.log(ngx.NOTICE, 'running first boot scripts')

local g = require('genupstream')
g.regen(os.getenv('GERRIT_HOST'), os.getenv('HTTP_PORT'),
    '/etc/nginx/upstreams.conf')
g.regen_resolved(os.getenv('GERRIT_HOST'), os.getenv('SSH_PORT'),
    '/etc/nginx/upstreams-ssh.conf')

-- use the account key as a marker for whether we've generated
-- keys yet or not
if ffi.C.access('/nginx-certs/account-key.pem', R_OK) ~= 0 or
   ffi.C.access('/nginx-certs/nginx-cert.pem', R_OK) ~= 0 then
	ngx.log(ngx.WARN, 'generating keys and initial self-signed cert')
	assert(os.execute(
	    '/usr/bin/openssl genrsa -out /nginx-certs/account-key.pem 2048') == 0)
	assert(os.execute(
	    '/usr/bin/openssl genrsa -out /nginx-certs/nginx-key.pem 2048') == 0)
	assert(os.execute(
	    '/usr/bin/openssl req -new -sha256 ' ..
	    '-key /nginx-certs/nginx-key.pem ' ..
	    '-subj "/CN=' .. os.getenv('MY_NAME') .. '" ' ..
	    '-out /nginx-certs/nginx-csr.pem') == 0)

	-- make a self-signed cert to start with, until the first ACME challenge
	-- succeeds
	assert(os.execute(
	    '/usr/bin/openssl x509 -req -days 1 -in /nginx-certs/nginx-csr.pem ' ..
	    '-signkey /nginx-certs/nginx-key.pem -out /nginx-certs/nginx-cert.pem') == 0)
	
	assert(os.execute(
	    'ln -sf nginx-main.conf /etc/nginx/nginx.conf') == 0)
end
