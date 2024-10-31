ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm-alpine
ARG NGINX_SERVER_NAME=localhost

# Instalace runtime a build balíčků, kompilace PHP rozšíření
RUN apk add --no-cache \
        bash \
        nginx \
        supervisor \
        curl \
        libmemcached \
        zlib \
        bzip2 \
        libxml2 \
        libpng \
        icu \
        gcompat \
        freetype \
        libjpeg-turbo \
        libwebp \
        libxslt \
        rabbitmq-c \
        gettext \
        libzip && \
    apk add --no-cache --virtual .build-deps \
        autoconf \
        make \
        gcc \
        g++ \
        curl-dev \
        libmemcached-dev \
        zlib-dev \
        bzip2-dev \
        oniguruma-dev \
        gmp-dev \
        libxml2-dev \
        libpng-dev \
        icu-dev \
        sqlite-dev \
        gettext-dev \
        libzip-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        libxslt-dev \
        rabbitmq-c-dev && \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && \
    docker-php-ext-install \
        bcmath \
        ctype \
        curl \
        fileinfo \
        gettext \
        gd \
        intl \
        mbstring \
        mysqli \
        opcache \
        pdo \
        pdo_mysql \
        simplexml \
        soap \
        zip \
        pcntl && \
    pecl install redis amqp memcached && \
    docker-php-ext-enable redis amqp memcached && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* /tmp/* /usr/share/man /usr/include/* /usr/lib/php/build

# Kopírování Composeru z oficiálního Composer obrazu
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Kopírování souborů a nastavení oprávnění
COPY ./rootfs /rootfs
COPY ./entrypoint.d /entrypoint.d
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN sed -i "s|server_name  _;|server_name ${NGINX_SERVER_NAME};|g" /rootfs/etc/nginx/http.d/default.conf
VOLUME ["/rootfs", "/entrypoint.d"]

# Nastavení pracovního adresáře
WORKDIR /app

# Definice entrypointu a CMD
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
