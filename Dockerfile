# syntax = docker/dockerfile:1.2
## Build intermediate container to handle Github token
FROM aro.jfrog.io/moodle/php:7.3-apache as composer

WORKDIR /

RUN apt-get update -y && \
	apt-get upgrade -y --fix-missing && \
	apt-get dist-upgrade -y && \
	dpkg --configure -a && \
	apt-get -f install && \
	apt-get install -y ssh-client && \
	apt-get install -y git && \
	apt-get install -o Dpkg::Options::="--force-confold" -y -q --no-install-recommends && apt-get clean -y \
		ca-certificates \
		libcurl4-openssl-dev \
		libgd-tools \
		libmcrypt-dev \
		default-mysql-client \
		vim \
		wget && \
	apt-get autoremove -y && \
	eval `ssh-agent -s` && \
	php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
	php composer-setup.php && \
	mv composer.phar /usr/local/bin/composer && \
	php -r "unlink('composer-setup.php');" && \
	rm -vfr /var/lib/apt/lists/*

#COPY .ssh/id_rsa /.ssh/id_rsa
COPY ./composer.json ./composer.json

#Define GitHub Auth Token
ARG GITHUB_AUTH_TOKEN
ENV COMPOSER_MEMORY_LIMIT=-1
# Add Github Auth token for Composer build, then install (GITHUB_AUTH_TOKEN.txt should be in root directory and contain the token only)
RUN --mount=type=secret,id=GITHUB_AUTH_TOKEN \
	composer config -g github-oauth.github.com $GITHUB_AUTH_TOKEN
RUN apt-get update -y && apt-get install -y unzip
#RUN composer install --optimize-autoloader --no-interaction --prefer-dist
RUN COMPOSER_PROCESS_TIMEOUT=2000 composer update --ignore-platform-reqs



##################################################
##################################################



# Build Moodle image
FROM aro.jfrog.io/moodle/php:7.3-apache as moodle

ARG CONTAINER_PORT=8080
ARG ENV_FILE=""

ENV APACHE_DOCUMENT_ROOT /vendor/moodle/moodle
ENV VENDOR=/vendor/
ENV COMPOSER_MEMORY_LIMIT=-1

EXPOSE $CONTAINER_PORT

RUN ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/1 /var/log/apache2/error.log && \
	apt-get update -y && \
	apt-get upgrade -y --fix-missing && \
	apt-get dist-upgrade -y && \
	dpkg --configure -a && \
	apt-get -f install && \
	apt-get install -y zlib1g-dev libicu-dev g++ && \
	apt-get install rsync && \
  	docker-php-ext-configure intl && \
	apt-get install tar && \
	apt-get install libxml2-dev -y && \
	set -eux; \
	\
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get install -y \
		cron \
		libfreetype6-dev \
		libjpeg-dev \libpng-dev \
		libpq-dev \
		libssl-dev \
		ca-certificates \
		libcurl4-openssl-dev \
		libgd-tools \
		libmcrypt-dev \
		zip \
		default-mysql-client \
		vim \
		wget \
		libbz2-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd --with-freetype-dir=/usr/include/  --with-jpeg-dir=/usr/include/ \
	; \
	\
	docker-php-ext-configure intl \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		pdo_mysql \
		xmlrpc \
		soap \
		zip \
		bcmath \
		bz2 \
		exif \
		ftp \
		gd \
		gettext \
		intl \
		mysqli \
		opcache \
		shmop \
		sysvmsg \
		sysvsem \
		sysvshm \
	; \
	\
	docker-php-ext-enable mysqli \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false;

RUN { \
		echo 'opcache.enable_cli=1'; \
		echo 'opcache.memory_consumption=1024'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=6000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'mysqli.default_socket=/var/run/mysqld/mysqld.sock'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini && \
	apt autoremove -y

# Copy files from intermediate build
COPY  --chown=www-data:www-data --from=composer $VENDOR $VENDOR
COPY  --chown=www-data:www-data --from=composer /usr/local/bin/composer /usr/local/bin/composer

WORKDIR /

# Don't copy .env to OpenShift - use Deployment Config > Environment instead
COPY .env$ENV_FILE ./.env

# COPY /app/config/sync/apache.conf /etc/apache2/sites-enabled/000-default.conf
COPY --chown=www-data:www-data app/config/sync/apache2.conf /etc/apache2/apache2.conf
COPY --chown=www-data:www-data app/config/sync/ports.conf /etc/apache2/ports.conf
COPY --chown=www-data:www-data app/config/sync/web-root.htaccess /vendor/moodle/moodle/.htaccess
COPY --chown=www-data:www-data app/config/sync/moodle/php.ini-development /usr/local/etc/php/php.ini
COPY --chown=www-data:www-data app/config/sync/moodle/moodle-config.php /vendor/moodle/moodle/config.php

USER root

# Setup Permissions for www user
RUN rm -rf /vendor/moodle/moodle/.htaccess && \
	mkdir -p /vendor/moodle/moodledata/ && \
	mkdir -p /vendor/moodle/moodledata/persistent && \
	if [ "$ENV_FILE" != ".local" ] ; then chown -R www-data:www-data /vendor/moodle ; fi && \
	if [ "$ENV_FILE" != ".local" ] ; then chown -R www-data:www-data /vendor/moodle/moodledata/persistent ; fi && \
	chgrp -R 0 /vendor/moodle/moodledata/persistent && \
	chmod -R g=u /vendor/moodle/moodledata/persistent && \
	chown -R www-data:www-data /vendor/moodle/moodledata/persistent && \
	chown -R www-data:www-data /vendor/moodle/moodledata/persistent

# chown -R www-data:www-data $VENDOR && \
# chown -R www-data:www-data /usr/local/etc/php/php.ini && \
# chown -R www-data:www-data /vendor/moodle && \
# chown -R www-data:www-data /vendor/moodle/moodledata/persistent && \
# chown -R www-data:www-data /usr/local/bin/composer && \
# chown -R www-data:www-data /vendor/moodle/moodle/config.php

# Add custom theme
# COPY app/config/sync/moodle/theme/bcgov /vendor/moodle/moodledata/theme/bcgov
# RUN chown -R www-data:www-data /vendor/moodle/moodledata/theme/bcgov
#Install and Enable mysqli
RUN docker-php-ext-install mysqli && \
      docker-php-ext-enable mysqli

#
# Add Cron Job for maintenance tasks
#
##RUN apt-get update && apt-get install -y cron
# Add crontab file in the cron directory
##ADD openshift/jobs/crontab.txt /etc/cron.d/moodle-cron
# Give execution rights on the cron job
##RUN chown -R www-data:www-data /etc/cron.d/moodle-cron
##RUN chmod 0644 /etc/cron.d/moodle-cron
# Apply cron job
##RUN crontab /etc/cron.d/moodle-cron
# Create the log file to be able to run tail
##RUN touch /var/log/cron.log
# Install Cron (above)
# Run the command on container startup
##RUN cron && tail -f /var/log/cron.log

## Can only have one CMD, so choose wisely
# docker
ENTRYPOINT ["apachectl", "-D", "FOREGROUND"]
# or OpenShift
#CMD /etc/init.d/apache2 start

# CMD ["cron", "-f"]
# CMD /etc/init.d/apache2 start
#ENTRYPOINT [ "/etc/init.d/apache2", "start"]
