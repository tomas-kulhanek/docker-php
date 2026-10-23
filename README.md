# Docker PHP

PHP-FPM, Nginx, Supervisor, and cron in one Alpine-based image. Application code is expected at `/app`, with the public document root at `/app/public`.

## Published images

| Registry | PHP versions | Tags |
| --- | --- | --- |
| GHCR: `ghcr.io/tomas-kulhanek/docker-php` | 8.3, 8.4, 8.5 | `<version>-latest`, `<version>-<full-commit-sha>` |
| Docker Hub: `kulhanekt/php` | 8.2, 8.3, 8.4, 8.5 | `<version>-latest`, `<version>-<full-commit-sha>` |

Both registries use PHP 8.4 for the unqualified `latest` tag. PHP 8.2 reaches upstream end of life on 31 December 2026; its Docker Hub tag should be retired then.

Publishing runs on every push to `main`, every Monday, and on manual dispatch. Each build pulls the current base image and fails if PHP lacks the security fixes introduced in PHP 8.2.35, 8.3.36, 8.4.27, and 8.5.12. The Docker Hub workflow requires the `DOCKERHUB_TOKEN` repository secret.

## Deployment and security

- Publish only HTTP port `8080`. Nginx is the only network-facing service. PHP-FPM listens on container loopback port `9000`; do not override it to a network-facing address.
- Put application secrets outside `/app/public`. Nginx also rejects hidden files under the public document root.
- Terminate TLS at a trusted reverse proxy. Configure allowed CORS origins in the application or trusted proxy; this image does not grant cross-origin access.
- PHP uses the production `php.ini`; errors go to container stderr and are not shown in responses.
- The Docker healthcheck calls the local Nginx endpoint `/php-fpm-ping`, which verifies the web server and PHP-FPM. It does not verify application dependencies such as a database.
- Nginx limits request bodies to 1 MiB. PHP's `post_max_size` is 8 MiB, so raise the Nginx limit and review PHP upload settings if an application needs larger uploads.
- OPcache revalidates application files every two seconds, including when code is supplied through a bind mount.

## Local builds

`make print` shows the resolved tags and platforms. `make` or `make build` builds PHP 8.3, 8.4, and 8.5 for `linux/amd64` and `linux/arm64`. `make push` publishes from a clean Git tree; only `main` updates the mutable `latest` tags. Other branches publish a tag containing the full commit SHA. Use `make build-8.4` or `make push-8.4` for one version.
