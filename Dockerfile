FROM alpine:3.4

ADD https://us-east.manta.joyent.com/arekinath/public/alpine-pkg/3.4/x86_64/nginx-common-1.10.1-r2.apk /tmp/
ADD https://us-east.manta.joyent.com/arekinath/public/alpine-pkg/3.4/x86_64/nginx-lua-1.10.1-r3.apk /tmp/
ADD https://raw.githubusercontent.com/diafygi/acme-tiny/master/acme_tiny.py /bin/acme_tiny

COPY ./overlay /

RUN	apk update && \
	apk add openssl python ca-certificates bind-tools && \
	apk add --allow-untrusted /tmp/nginx-common-1.10.1-r2.apk && \
	apk add --allow-untrusted /tmp/nginx-lua-1.10.1-r3.apk && \
	rm -f /tmp/*.apk && \
	chmod a+x /bin/acme_tiny && \
	mkdir /var/lib/nginx/acme && chown nginx /var/lib/nginx/acme && \
	mkdir /nginx-certs && chown nginx /nginx-certs && \
	ln -sf nginx-firstrun.conf /etc/nginx/nginx.conf

VOLUME /nginx-certs

EXPOSE 80 443 22 29418
ENTRYPOINT ["/usr/sbin/nginx"]
