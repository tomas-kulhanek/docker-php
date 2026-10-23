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

# PHP 8.2 bundles IMAP; the PECL release requires PHP 8.3 or newer.
RUN set -eux; \
    if [ "$(php -r 'echo PHP_VERSION_ID;')" -lt 80300 ]; then \
      docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
      docker-php-ext-install -j"$(nproc)" imap; \
    else \
      pecl install imap-1.0.3; \
      docker-php-ext-enable imap; \
    fi

RUN set -eux; \
    [ -e /usr/lib/libsybdb.so ] || ln -s /usr/lib/libsybdb.so.5 /usr/lib/libsybdb.so || true; \
    docker-php-ext-install -j"$(nproc)" pdo_dblib

# ctype curl dom fileinfo filter mbstring opcache pdo_sqlite session simplexml
# sodium xml are compiled into the base image (rebuilding dom fails on 8.5 - lexbor)
RUN docker-php-ext-install -j"$(nproc)" \
    bcmath bz2 calendar exif ftp gettext gmp intl mysqli \
    pcntl pdo_mysql soap tidy zip xsl

RUN docker-php-ext-configure gd --with-jpeg --with-xpm --with-webp --with-freetype && \
    docker-php-ext-install -j"$(nproc)" gd

COPY --from=ghcr.io/php/pie:1.5.2-bin@sha256:a254c78b51ca34daef0541fa1cf0147385c93ba5ca799868392275d947f00fe7 /pie /usr/bin/pie

# PIE enables each extension itself (conf.d ini); igbinary has only an RC on Packagist
RUN set -eux; \
    for pkg in \
      php-amqp/php-amqp phpredis/phpredis php-ds/ext-ds php-memcached/php-memcached \
      igbinary/igbinary:3.2.17RC1 apcu/apcu msgpack/msgpack-php \
    ; do pie install --no-interaction "$pkg"; done


FROM php:${PHP_VERSION}-fpm-alpine AS runtime

ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so.0
ENV TZ=Europe/Prague
ENV PYTHONWARNINGS="ignore:pkg_resources"

# Introduced in PHP 8.2.35, 8.3.36, 8.4.27 and 8.5.12.
RUN set -eux; \
    cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    php -r 'if (ini_get("memory_hard_limit_percent") === false) { fwrite(STDERR, "PHP security release required\n"); exit(1); }'; \
    apk add --no-cache \
      supervisor nginx dcron \
      tzdata ca-certificates bash curl \
      libzip zlib bzip2 \
      libxml2 libxslt \
      icu-libs \
      openssl krb5-libs \
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

# The PHP base entrypoint does not run /entrypoint.d.
RUN cp -a /rootfs/. / && \
    php -r 'if (ini_get("memory_limit") !== "256M" || ini_get("post_max_size") !== "8M" || ini_get("max_input_nesting_level") !== "4" || ini_get("session.upload_progress.enabled") !== "0" || ini_get("expose_php") !== "0" || ini_get("display_errors") !== "" || ini_get("log_errors") !== "1") { fwrite(STDERR, "PHP hardening configuration not loaded\n"); exit(1); }' && \
    php-fpm -t && nginx -t

RUN printf '%s\n' '#!/bin/sh' 'exec /usr/sbin/crond -f -l 8' > /usr/sbin/cron && chmod +x /usr/sbin/cron

RUN printf '%s\n' \
      '#!/bin/sh' \
      'set -eu' \
      'curl --fail --silent --show-error --max-time 3 http://127.0.0.1:8080/php-fpm-ping | grep -qx pong' \
      > /healthcheck && chmod +x /healthcheck

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD ["/healthcheck"]

WORKDIR /app

LABEL maintainer="Tomas Kulhanek <jsem@tomaskulhanek.cz>"
LABEL version="PHP ${PHP_VERSION}"
LABEL description="Docker image with PHP-FPM ${PHP_VERSION} on PHP Alpine image, supervisor, nginx, cron"

CMD ["supervisord","-c","/etc/supervisord.conf"]

EXPOSE 8080
