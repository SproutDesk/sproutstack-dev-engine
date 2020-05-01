FROM php:7.1-fpm-alpine as base

MAINTAINER Rhys Botfield <rhys@sproutdesk.co.uk>

ENV _BUILD_DEPS \
		libpng-dev \
		jpeg-dev \
		freetype-dev \
		icu-dev \
		libmcrypt-dev \
		libxml2-dev \
		libxslt-dev

RUN apk add --no-cache libpng \
		libjpeg-turbo \
		freetype \
		icu \
		libmcrypt \
		libxslt \
		${_BUILD_DEPS} \
	&& docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr --with-freetype-dir=/usr \
	&& docker-php-ext-install gd pdo_mysql soap xsl mysqli intl bcmath zip mcrypt \
	&& apk del ${_BUILD_DEPS}

# PECL extensions
RUN apk add --no-cache ${PHPIZE_DEPS} \
	&& pecl install -o -f redis-5.2.1 \
	&& docker-php-ext-enable redis \
	&& apk del ${PHPIZE_DEPS}

# Blackfire.io
RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/alpine/amd64/$version \
    && mkdir -p /tmp/blackfire \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
    && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
    && printf "extension=blackfire.so\nblackfire.agent_socket=tcp://0.0.0.0:8707\nblackfire.log_file=/var/log/php-fpm/blackfire.log\n" > $PHP_INI_DIR/conf.d/blackfire.ini \
    && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz

RUN mkdir /var/log/php-fpm/
RUN rm /usr/local/etc/php-fpm.d/zz-docker.conf
ADD ./www.conf /usr/local/etc/php-fpm.d/www.conf

RUN apk add --no-cache ssmtp
ADD ./ssmtp.conf /etc/ssmtp/ssmtp.conf

ENV PHP71_ENABLE=true
CMD /bin/sh -c "/bin/${PHP71_ENABLE:-true} && php-fpm"

FROM base as ioncube
RUN curl -o ioncube_loaders_lin_x86-64.tar.gz http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz \
	&& tar xfz ioncube_loaders_lin_x86-64.tar.gz \
	&& cp ioncube/ioncube_loader_lin_7.1.so /usr/local/lib/php/extensions/no-debug-non-zts-20160303/ \
	&& echo "zend_extension=ioncube_loader_lin_7.1.so" > $PHP_INI_DIR/conf.d/00_docker-php-ext-ioncube_loader_lin_7.1.ini \
	&& rm -Rf ioncube_loaders_lin_x86-64.tar.gz ioncube

FROM base as xdebug
RUN apk add --no-cache ${PHPIZE_DEPS} \
	&& pecl install -o -f xdebug-2.9.5 \
	&& docker-php-ext-enable xdebug \
	&& apk del ${PHPIZE_DEPS}
ADD ./xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini
