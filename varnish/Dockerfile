FROM alpine:3.11

MAINTAINER Rhys Botfield <rhys@sproutdesk.co.uk>

RUN apk add --no-cache varnish

ADD default.vcl /etc/varnish/default.vcl

ENV VARNISH_ENABLE=true
CMD /bin/sh -c "/bin/${VARNISH_ENABLE} && varnishd -f /etc/varnish/default.vcl -a :8888 -s malloc,128m && varnishlog -w /var/log/varnish/varnish.log -A"
