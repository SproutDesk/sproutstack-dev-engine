FROM phpmyadmin/phpmyadmin:fpm-alpine

RUN mv /var/www/html /phpmyadmin
RUN mkdir /var/log/php-fpm/
RUN rm /usr/local/etc/php-fpm.d/zz-docker.conf
ADD ./www.conf /usr/local/etc/php-fpm.d/www.conf