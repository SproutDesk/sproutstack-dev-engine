FROM nginx:1.18-alpine

MAINTAINER Rhys Botfield <rhys@sproutdesk.co.uk>

RUN apk add --no-cache openssl \
&& mkdir -p /etc/nginx/ssl/ \
    && openssl req -x509 -newkey rsa:4086 -keyout /etc/nginx/ssl/privkey.pem -out /etc/nginx/ssl/cert.pem \
    -days 3650 -nodes -sha256 -subj "/C=GB/ST=Manchester/L=Manchester/O=SproutDesk/OU=development/CN=sproutdesk.local" \
&& apk del openssl

ADD nginx.conf /etc/nginx/nginx.conf
ADD fastcgi_params /etc/nginx/fastcgi_params
ADD templates/ /etc/nginx/templates/

RUN rm -rf /usr/share/nginx/html
ADD html/ /usr/share/nginx/html
