## What

A docker image with an nginx that automatically requests and renews a
LetsEncrypt certificate to put HTTPS in front of your gerrit.

Also forwards port 22 and 29418 to the gerrit server.

## Using

You probably want to use the docker gerrit, and set
`-e WEBURL=proxy-https://gerrit.svc.blah.us-east-3b.triton.zone`

Then to set up the nginx:

```
# docker pull arekinath/gerrit-nginx
# docker run -d \
	-l triton.cns.services=gerrit \
	-e MY_NAME=gerrit.svc.blah.us-east-3b.triton.zone \
	-e GERRIT_HOST=gerrit-backend.svc.blah.us-east-3b.cns.joyent.com \
	-e SSH_PORT=29418 -e HTTP_PORT=8080 \
	-p 80 -p 443 -p 22 -o 29418 \
	arekinath/gerrit-nginx
```
