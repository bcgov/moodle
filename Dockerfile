# syntax = docker/dockerfile:1.2
# Build intermediate container to handle Github token
FROM aro.jfrog.io/moodle/php:8.2-apache as composer

ENV APACHE_DOCUMENT_ROOT /vendor/moodle/moodle

# Version control for Moodle and plugins
ENV MOODLE_BRANCH_VERSION MOODLE_402_STABLE
ENV F2F_BRANCH_VERSION MOODLE_400_STABLE
ENV HVP_BRANCH_VERSION stable
ENV FORMAT_BRANCH_VERSION MOODLE_402
# ENV CERTIFICATE_BRANCH_VERSION MOODLE_31_STABLE
ENV CUSTOMCERT_BRANCH_VERSION MOODLE_402_STABLE
ENV DATAFLOWS_BRANCH_VERSION MOODLE_401_STABLE

WORKDIR /

RUN apt-get update -y && \
	apt-get upgrade -y --fix-missing && \
	apt-get dist-upgrade -y && \
	dpkg --configure -a && \
	apt-get -f install && \
	apt-get install -y ssh-client && \
    apt-get install -y zip && \
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

ARG GITHUB_AUTH_TOKEN=""
ENV COMPOSER_MEMORY_LIMIT=-1

# Add Github Auth token for Composer build, then install (GITHUB_AUTH_TOKEN.txt should be in root directory and contain the token only)
RUN --mount=type=secret,id=GITHUB_AUTH_TOKEN \
composer config -g github-oauth.github.com $GITHUB_AUTH_TOKEN

RUN composer install --optimize-autoloader --no-interaction --prefer-dist

# Add plugins (try to add these via composer later)
#RUN mkdir -p /vendor/moodle

RUN git clone --recurse-submodules --jobs 8 --branch $MOODLE_BRANCH_VERSION --single-branch https://github.com/moodle/moodle /vendor/moodle/moodle

RUN mkdir -p /vendor/moodle/moodle/admin/tool/trigger && \
    mkdir -p /vendor/moodle/moodle/admin/tool/dataflows && \
    mkdir -p /vendor/moodle/moodle/mod/facetoface && \
    mkdir -p /vendor/moodle/moodle/mod/hvp  && \
    mkdir -p /vendor/moodle/moodle/course/format/topcoll  && \
#    mkdir -p /vendor/moodle/moodle/mod/certificate  && \
    mkdir -p /vendor/moodle/moodle/mod/customcert  && \
    chown -R www-data:www-data /vendor/moodle/moodle/admin/tool/ && \
    chown -R www-data:www-data /vendor/moodle/moodle/mod/ && \
    chown -R www-data:www-data /vendor/moodle/moodle/course/format/

RUN git clone --recurse-submodules --jobs 8 https://github.com/catalyst/moodle-tool_trigger /vendor/moodle/moodle/admin/tool/trigger && \
    git clone --recurse-submodules --jobs 8 --branch $DATAFLOWS_BRANCH_VERSION --single-branch https://github.com/catalyst/moodle-tool_dataflows.git /vendor/moodle/moodle/admin/tool/dataflows && \
    git clone --recurse-submodules --jobs 8 --branch $F2F_BRANCH_VERSION --single-branch https://github.com/catalyst/moodle-mod_facetoface /vendor/moodle/moodle/mod/facetoface && \
    git clone --recurse-submodules --jobs 8 --branch $HVP_BRANCH_VERSION --single-branch https://github.com/h5p/moodle-mod_hvp /vendor/moodle/moodle/mod/hvp && \
    git clone --recurse-submodules --jobs 8 --branch $FORMAT_BRANCH_VERSION --single-branch https://github.com/gjb2048/moodle-format_topcoll /vendor/moodle/moodle/course/format/topcoll && \
    git clone --recurse-submodules --jobs 8 --branch $CUSTOMCERT_BRANCH_VERSION --single-branch https://github.com/mdjnelson/moodle-mod_customcert /vendor/moodle/moodle/mod/customcert

# git clone --recurse-submodules --jobs 8 --branch $CERTIFICATE_BRANCH_VERSION --single-branch https://github.com/mdjnelson/moodle-mod_certificate /vendor/moodle/moodle/mod/certificate

# RUN git submodule update --init

##################################################
##################################################



# Build Moodle image
FROM aro.jfrog.io/moodle/php:8.2-apache as moodle

ARG CONTAINER_PORT=8080
ARG ENV_FILE=""
ARG CRONTAB="FALSE"
ARG DB_HOST="localhost"
ARG DB_NAME="moodle"
ARG DB_PASSWORD=""
ARG DB_USER="moodle"

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
	apt-get install rsync grsync && \
	apt-get install tar && \
	set -eux; \
	\
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	docker-php-ext-install -j "$(nproc)" \
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


# Enable PHP extensions - full list:
# bcmath bz2 calendar ctype curl dba dom enchant exif fileinfo filter ftp gd gettext gmp hash iconv imap interbase intl json ldap mbstring mysqli oci8 odbc opcache pcntl pdo pdo_dblib pdo_firebird pdo_mysql pdo_oci pdo_odbc pdo_pgsql pdo_sqlite pgsql phar posix pspell readline recode reflection session shmop simplexml snmp soap sockets sodium spl standard sysvmsg sysvsem sysvshm tidy tokenizer wddx xml xmlreader xmlrpc xmlwriter xsl zend_test zip

ENV PHP_EXTENSIONS="mysqli xmlrpc soap zip bcmath bz2 exif ftp gd gettext intl opcache shmop sysvmsg sysvsem sysvshm"

#RUN docker-php-ext-install $PHP_EXTENTIONS  && \
#    docker-php-ext-enable $PHP_EXTENTIONS
RUN apt-get install libxml2-dev -y
RUN apt-get install libzip-dev -y
RUN apt-get update && apt-get install -y libbz2-dev

#Install rsync
RUN apt-get install rsync -y \
  && pecl install channel://pecl.php.net/xmlrpc-1.0.0RC3

RUN apt-get install cron -y && \
    apt-get install libfreetype6-dev -y && \
    apt-get install libjpeg-dev \libpng-dev -y && \
    apt-get install libpq-dev -y && \
    apt-get install libssl-dev -y && \
    apt-get install ca-certificates -y && \
    apt-get install libcurl4-openssl-dev -y && \
    apt-get install libgd-tools -y && \
    apt-get install libmcrypt-dev -y && \
    apt-get install zip -y && \
    apt-get install default-mysql-client -y && \
    apt-get install vim -y && \
    apt-get install wget -y && \
    apt-get install graphviz -y && \
    apt-get install libbz2-dev -y

RUN docker-php-ext-install mysqli && \
    docker-php-ext-install soap && \
    docker-php-ext-install zip && \
    docker-php-ext-install bcmath && \
    docker-php-ext-install bz2 && \
    docker-php-ext-install exif && \
    docker-php-ext-install ftp && \
    docker-php-ext-install gd && \
    docker-php-ext-install gettext && \
    docker-php-ext-install intl && \
    docker-php-ext-install opcache && \
    docker-php-ext-install shmop && \
    docker-php-ext-install sysvmsg && \
    docker-php-ext-install sysvsem && \
    docker-php-ext-install sysvshm && \
    docker-php-ext-enable gd && \
    docker-php-ext-enable intl && \
    docker-php-ext-enable mysqli && \
    docker-php-ext-enable soap && \
    docker-php-ext-enable xmlrpc && \
    docker-php-ext-enable zip && \
    docker-php-ext-configure intl && \
    docker-php-ext-configure gd --with-freetype --with-jpeg

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
###COPY  --chown=www-data:www-data --from=composer /usr/local/bin/composer /usr/local/bin/composer

WORKDIR /

# Don't copy .env to OpenShift - use Deployment Config > Environment instead
COPY .env$ENV_FILE ./.env

USER root

# Use ONE of these - High Availability (-ha-readonly) or standard
#COPY --chown=www-data:www-data app/config/sync/moodle/moodle-config-no-composer.php /vendor/moodle/moodle/config.php
COPY --chown=www-data:www-data app/config/sync/moodle/moodle-config.php /vendor/moodle/moodle/config.php

# Find/replace config values to make the file solid for CLI/Cron (not using ENV vars)
RUN sed -i "s|DB_HOST|${DB_HOST}|" /vendor/moodle/moodle/config.php
RUN sed -i "s|DB_NAME|${DB_NAME}|" /vendor/moodle/moodle/config.php
RUN sed -i "s|DB_USER|${DB_USER}|" /vendor/moodle/moodle/config.php
RUN sed -i "s|DB_PASSWORD|${DB_PASSWORD}|" /vendor/moodle/moodle/config.php

# COPY /app/config/sync/apache.conf /etc/apache2/sites-enabled/000-default.conf
COPY --chown=www-data:www-data app/config/sync/apache2.conf /etc/apache2/apache2.conf
COPY --chown=www-data:www-data app/config/sync/apache2-mods-available-mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf
COPY --chown=www-data:www-data app/config/sync/ports.conf /etc/apache2/ports.conf
COPY --chown=www-data:www-data app/config/sync/web-root.htaccess /vendor/moodle/moodle/.htaccess
COPY --chown=www-data:www-data app/config/sync/moodle/php.ini-development /usr/local/etc/php/php.ini

# Setup Permissions for www user
RUN rm -rf /vendor/moodle/moodle/.htaccess && \
    mkdir -p /vendor/moodle/moodledata/ && \
    mkdir -p /vendor/moodle/moodledata/persistent && \
    if [ "$ENV_FILE" != ".local" ] ; then chown -R www-data:www-data /vendor/moodle ; fi && \
    if [ "$ENV_FILE" != ".local" ] ; then chown -R www-data:www-data /vendor/moodle/moodle/mod ; fi && \
    if [ "$ENV_FILE" != ".local" ] ; then chown -R www-data:www-data /vendor/moodle/moodledata/persistent ; fi && \
    chgrp -R 0 ${APACHE_DOCUMENT_ROOT} && \
    chmod -R g=u ${APACHE_DOCUMENT_ROOT} && \
    chown -R www-data:www-data ${APACHE_DOCUMENT_ROOT} && \
    chgrp -R 0 /vendor/moodle/moodledata/persistent && \
    chmod -R g=u /vendor/moodle/moodledata/persistent && \
    chown -R www-data:www-data /vendor/moodle/moodledata/persistent && \
    chgrp -R 0 /.env && \
    chmod -R g=u /.env && \
    chown -R www-data:www-data /vendor/moodle/moodle/mod && \
    chgrp -R 0 /vendor/moodle/moodle/mod && \
    chmod -R g=u /vendor/moodle/moodle/mod && \
    chown -R www-data:www-data /var/run/apache2

ENTRYPOINT ["apachectl", "-D", "FOREGROUND"]
