ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm-alpine
ARG NGINX_SERVER_NAME=localhost
LABEL maintainer="Tomáš Kulhánek <jsem@tomaskulhanek.cz>"

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY ./rootfs /rootfs
COPY ./entrypoint.d /entrypoint.d

RUN apk --update --no-cache add bash multirun nginx libzip-dev zip jq g++ make rabbitmq-c-dev libpng-dev oniguruma-dev autoconf supervisor curl-dev libxml2-dev icu-dev libpng-dev libjpeg-turbo-dev freetype-dev && \
    docker-php-ext-configure bcmath --enable-bcmath && \
    docker-php-ext-configure gd --with-jpeg --with-freetype && \
    docker-php-ext-install pdo_mysql bcmath gd zip pcntl curl soap intl gd && \
	pecl install redis amqp && \
	docker-php-ext-enable redis amqp pcntl curl soap intl && \
    docker-php-source delete && \
    apk del g++ make && \
    sed -i "s|server_name  _;|server_name ${NGINX_SERVER_NAME};|g" /rootfs/etc/nginx/http.d/default.conf

WORKDIR /app