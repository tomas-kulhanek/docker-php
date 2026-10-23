#!/usr/bin/env bash
set -euo pipefail

image=${1:?Usage: smoke.sh IMAGE}
container="docker-php-smoke-$$"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$container" -p 127.0.0.1::8080 "$image" >/dev/null
docker exec -i "$container" sh <<'SH'
mkdir -p /app/public
mkdir -p /app/public/.well-known/acme-challenge
cat > /app/public/index.php <<'PHP'
<?php
trigger_error('SMOKE_WARNING', E_USER_WARNING);
header('Content-Type: text/plain');
echo 'APP_OK';
PHP
printf '%s\n' 'SHOULD_NOT_BE_PUBLIC' > /app/public/.env
printf '%s\n' 'ACME_OK' > /app/public/.well-known/acme-challenge/token
SH

for ((attempt = 0; attempt < 60; attempt++)); do
    if [ "$(docker inspect --format '{{.State.Health.Status}}' "$container")" = healthy ]; then
        break
    fi
    sleep 1
done
test "$(docker inspect --format '{{.State.Health.Status}}' "$container")" = healthy

port=$(docker port "$container" 8080/tcp | awk -F: '{print $NF}')
base_url="http://127.0.0.1:$port"

test "$(curl --fail --silent --show-error "$base_url/")" = APP_OK
test "$(curl --fail --silent --show-error "$base_url/route.json")" = APP_OK
test "$(curl --silent --output /dev/null --write-out '%{http_code}' "$base_url/.env")" = 404
test "$(curl --fail --silent --show-error "$base_url/.well-known/acme-challenge/token")" = ACME_OK
test "$(curl --silent --output /dev/null --write-out '%{http_code}' "$base_url/fpm-status")" = 403
fpm_config=$(docker exec "$container" php-fpm -tt 2>&1)
[[ "$fpm_config" == *'listen = 127.0.0.1:9000'* ]]
docker exec "$container" php -r '$ip = gethostbyname(gethostname()); if (!filter_var($ip, FILTER_VALIDATE_IP) || $ip === "127.0.0.1") exit(2); $socket = @fsockopen($ip, 9000, $code, $message, 1); if ($socket) { fclose($socket); exit(1); }'
logs=$(docker logs "$container" 2>&1)
[[ "$logs" == *SMOKE_WARNING* ]]
if docker exec -u www-data "$container" supervisorctl -s http://127.0.0.1:9006 status >/dev/null 2>&1; then
    echo 'Unprivileged users can access Supervisor HTTP' >&2
    exit 1
fi
if docker exec -u www-data "$container" supervisorctl status >/dev/null 2>&1; then
    echo 'Unprivileged users can access Supervisor control socket' >&2
    exit 1
fi

docker exec "$container" supervisorctl stop nginx >/dev/null
if docker exec "$container" /healthcheck >/dev/null 2>&1; then
    echo 'Healthcheck passed while Nginx was stopped' >&2
    exit 1
fi
docker exec "$container" supervisorctl start nginx >/dev/null

echo "Smoke test passed for $image"
