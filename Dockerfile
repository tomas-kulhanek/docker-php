ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm-alpine AS build

ENV TZ=Europe/Prague

RUN set -eux; \
    apk add --no-cache \
      tzdata \
      $PHPIZE_DEPS build-base libtool automake pkgconf re2c \
      libzip-dev zlib-dev bzip2-dev \
      libxml2-dev libxslt-dev \
      icu-dev \
      openssl-dev krb5-dev \
      curl-dev \
      gmp-dev \
      rabbitmq-c-dev \
      libmemcached-dev cyrus-sasl-dev \
      libpng-dev libjpeg-turbo-dev libwebp-dev libxpm-dev freetype-dev \
      gd-dev \
      pcre2-dev \
      sqlite-dev \
      tidyhtml-dev file-dev \
      libsodium-dev \
      libssh2-dev \
      freetds-dev \
      gettext-dev \
      gnu-libiconv-dev \
      imap-dev c-client \
      oniguruma-dev \
      ca-certificates curl wget git jq unzip zip bash \
    ; \
    if [ -e "/usr/share/zoneinfo/${TZ}" ]; then ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime; fi; \
    echo "${TZ}" > /etc/timezone

RUN set -eux; \
    export CFLAGS="${CFLAGS:-}"; \
    export LDFLAGS="${LDFLAGS:-} -L/usr/lib"; \
    export LIBS="${LIBS:-} -liconv"; \
    docker-php-ext-configure iconv --with-iconv=/usr; \
    docker-php-ext-install -j"$(nproc)" iconv

RUN set -eux; \
    pecl install imap && docker-php-ext-enable imap

RUN set -eux; \
    [ -e /usr/lib/libsybdb.so ] || ln -s /usr/lib/libsybdb.so.5 /usr/lib/libsybdb.so || true; \
    docker-php-ext-install -j"$(nproc)" pdo_dblib

RUN docker-php-ext-install -j"$(nproc)" \
    bcmath bz2 calendar ctype curl dom fileinfo filter exif ftp \
    gettext gmp intl mbstring mysqli opcache pcntl pdo_mysql \
    pdo_sqlite session simplexml soap sodium tidy zip xsl xml

RUN docker-php-ext-configure gd --with-jpeg --with-xpm --with-webp --with-freetype && \
    docker-php-ext-install -j"$(nproc)" gd

RUN set -eux; \
    pecl install amqp redis ds memcached igbinary apcu msgpack; \
    docker-php-ext-enable amqp redis ds memcached igbinary apcu msgpack


FROM php:${PHP_VERSION}-fpm-alpine AS runtime

ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so.0
ENV TZ=Europe/Prague
ENV PYTHONWARNINGS="ignore:pkg_resources"

RUN set -eux; \
    apk add --no-cache \
      supervisor nginx rsyslog fcgi dcron \
      tzdata ca-certificates bash curl lsof \
      libzip zlib bzip2 \
      libxml2 libxslt \
      icu-libs \
      openssl krb5-libs \
      curl \
      gmp \
      rabbitmq-c \
      libmemcached cyrus-sasl \
      libpng libjpeg-turbo libwebp libxpm freetype \
      gd \
      pcre2 \
      sqlite-libs \
      tidyhtml-libs file \
      libsodium \
      libssh2 \
      freetds \
      gettext-libs \
      gnu-libiconv \
      oniguruma \
      c-client \
    ; \
    if [ -e "/usr/share/zoneinfo/${TZ}" ]; then ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime; fi; \
    echo "${TZ}" > /etc/timezone; \
    mkdir -p /var/log/supervisor /run/nginx

COPY --from=build /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

COPY ./rootfs /rootfs
COPY ./entrypoint.d /entrypoint.d

RUN printf '%s\n' \
  '[supervisord]' \
  'nodaemon=true' \
  'user=root' \
  '' \
  '[rpcinterface:supervisor]' \
  'supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface' \
  '' \
  '[supervisorctl]' \
  'serverurl=http://127.0.0.1:9006' \
  '' \
  '[include]' \
  'files = /etc/supervisor/conf.d/*.conf' \
  > /etc/supervisord.conf

RUN printf '%s\n' '#!/bin/sh' 'exec /usr/sbin/crond -f -l 8' > /usr/sbin/cron && chmod +x /usr/sbin/cron

RUN echo '#!/bin/sh' > /healthcheck && \
    echo 'env -i SCRIPT_NAME=/health SCRIPT_FILENAME=/health REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1' >> /healthcheck && \
    chmod +x /healthcheck

WORKDIR /app

LABEL maintainer="Tomas Kulhanek <jsem@tomaskulhanek.cz>"
LABEL version="PHP ${PHP_VERSION}"
LABEL description="Docker image with PHP-FPM ${PHP_VERSION} on PHP Alpine image, supervisor, nginx, cron"

CMD ["supervisord","-c","/etc/supervisord.conf"]

EXPOSE 9006 9000 8080
