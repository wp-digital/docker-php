#!/bin/sh
set -eu

image="${1:-docker-php/php-7.4-newrelic-10.7.0.319:local}"
platform="${2:-linux/amd64}"
expected_php_series="${EXPECTED_PHP_SERIES-7.4}"
expected_php_version="${EXPECTED_PHP_VERSION-7.4.33}"
expected_patch_commit="${EXPECTED_PATCH_COMMIT-712e60f9edfd03f0960fc4fc3c2c375f42b90aa2}"
security_patch_file="${SECURITY_PATCH_FILE-php-7.4-cve-2026-109618-109619.patch}"
container_id=''

if [ -z "$expected_php_series" ]; then
	echo 'EXPECTED_PHP_SERIES must not be empty' >&2
	exit 1
fi

if [ -n "$expected_patch_commit" ] && [ -z "$security_patch_file" ]; then
	echo 'SECURITY_PATCH_FILE must not be empty when EXPECTED_PATCH_COMMIT is set' >&2
	exit 1
fi

cleanup() {
	if [ -n "$container_id" ]; then
		docker rm --force "$container_id" >/dev/null 2>&1 || true
	fi
}

trap cleanup 0 1 2 15

echo "Testing image: $image"
docker image inspect "$image" >/dev/null

echo 'Checking PHP version'
actual_php_version="$(docker run --rm --platform "$platform" --entrypoint php "$image" -r 'echo PHP_VERSION;')"
if [ -n "$expected_php_version" ] && [ "$actual_php_version" != "$expected_php_version" ]; then
	echo "Expected PHP $expected_php_version, got $actual_php_version" >&2
	exit 1
fi
case "$actual_php_version" in
	"$expected_php_series".*) ;;
	*)
		echo "Expected PHP $expected_php_series.x, got $actual_php_version" >&2
		exit 1
		;;
esac

echo 'Checking required PHP extensions'
modules="$(docker run --rm --platform "$platform" --entrypoint php "$image" -m)"
for extension in bcmath exif gd imagick intl mysqli newrelic redis SimpleXML soap zip; do
	if ! printf '%s\n' "$modules" | grep -Fxq "$extension"; then
		echo "Missing PHP extension: $extension" >&2
		exit 1
	fi
done
printf '%s\n' "$modules" | grep -Fxq 'Zend OPcache'

echo 'Checking bundled tools'
docker run --rm --platform "$platform" --entrypoint composer "$image" --version --no-ansi 2>&1 \
	| grep -Fq 'Composer version 2.10.1'
docker run --rm --platform "$platform" --entrypoint wp "$image" cli version \
	| grep -Fxq 'WP-CLI 2.12.0'

echo 'Checking PHP-FPM configuration'
if ! docker run --rm --platform "$platform" "$image" \
	php-fpm -d newrelic.daemon.dont_launch=3 -tt >/dev/null; then
	echo 'PHP-FPM failed with the complete extension configuration; running diagnostics' >&2

	echo 'Diagnostic: PHP-FPM core without php.ini files' >&2
	docker run --rm --platform "$platform" --entrypoint php-fpm "$image" \
		-n -tt >/dev/null || true

	echo 'Diagnostic: PHP-FPM with only New Relic loaded' >&2
	docker run --rm --platform "$platform" --entrypoint php-fpm "$image" \
		-n \
		-d extension=newrelic.so \
		-d newrelic.daemon.dont_launch=3 \
		-tt >/dev/null || true

	echo 'Diagnostic: complete configuration without New Relic' >&2
	docker run --rm --platform "$platform" --entrypoint sh "$image" -eu -c '
		mv /usr/local/etc/php/conf.d/newrelic.ini /tmp/newrelic.ini
		exec php-fpm -tt
	' >/dev/null || true

	exit 1
fi

echo 'Checking security patch provenance'
if [ -n "$expected_patch_commit" ]; then
	actual_patch_commit="$(
		docker image inspect \
			--format '{{ index .Config.Labels "com.wp-digital.php.security-patch.commit" }}' \
			"$image"
	)"
	if [ "$actual_patch_commit" != "$expected_patch_commit" ]; then
		echo "Unexpected security patch commit label: $actual_patch_commit" >&2
		exit 1
	fi
	provenance_file="/usr/local/share/php-security-patches/${security_patch_file%.patch}.md"
	docker run --rm --platform "$platform" --entrypoint sh "$image" -eu -c \
		'test -s "$1" && grep -Fq "$2" "$1"' sh "$provenance_file" "$expected_patch_commit"
fi

echo 'Checking New Relic entrypoint configuration'
docker run --rm \
	--platform "$platform" \
	-e NEWRELIC_LICENSE=smoke-test-license \
	-e NEWRELIC_APP_NAME=docker-php-smoke-test \
	"$image" sh -eu -c '
		config=/usr/local/etc/php/conf.d/newrelic.ini
		grep -Fxq "extension = newrelic.so" "$config"
		grep -Fxq "newrelic.license = smoke-test-license" "$config"
		grep -Fxq "newrelic.appname = docker-php-smoke-test" "$config"
	'

echo 'Checking that the default PHP-FPM process stays running'
container_id="$(
	docker run --detach \
		--platform "$platform" \
		-e NEWRELIC_LICENSE=smoke-test-license \
		-e NEWRELIC_APP_NAME=docker-php-smoke-test \
		"$image"
)"
sleep 2
if [ "$(docker inspect --format '{{ .State.Running }}' "$container_id")" != 'true' ]; then
	docker logs "$container_id" >&2
	exit 1
fi
docker exec "$container_id" php -r 'echo "PHP-FPM runtime OK", PHP_EOL;' \
	| grep -Fxq 'PHP-FPM runtime OK'

cleanup
container_id=''

echo "All PHP $expected_php_series image smoke tests passed."
