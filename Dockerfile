ARG PHP_BASE_IMAGE=php:7.4.33-fpm-alpine3.16@sha256:0aeb129a60daff2874c5c70fcd9d88cdf3015b4fb4cc7c3f1a32a21e84631036
ARG PHP_VERSION_SERIES=7.4
ARG PHP_EXPECTED_VERSION=7.4.33
ARG PHP_SECURITY_PATCH_FILE=php-7.4-cve-2026-109618-109619.patch
ARG PHP_SECURITY_PATCH_IDS=CVE-2026-109618,CVE-2026-109619
ARG PHP_SECURITY_PATCH_COMMIT=712e60f9edfd03f0960fc4fc3c2c375f42b90aa2
ARG PHP_SECURITY_PATCH_SHA256=4ce7225e512ed559ac92ef9934f00399b1083f5371dc82e1c535bdfa9d74664f
ARG PHP_REBUILD_COMPAT_PATCH_FILE=
ARG PHP_REBUILD_COMPAT_PATCH_SHA256=
ARG COMPOSER_IMAGE=composer:2.10.1@sha256:7725eb4545c438629ae8bde3ef0bb9a5038ef566126ad878442a69007242d267

FROM ${COMPOSER_IMAGE} AS composer-bin

FROM ${PHP_BASE_IMAGE} AS patched-php

ARG PHP_EXPECTED_VERSION
ARG PHP_SECURITY_PATCH_FILE
ARG PHP_SECURITY_PATCH_SHA256
ARG PHP_REBUILD_COMPAT_PATCH_FILE
ARG PHP_REBUILD_COMPAT_PATCH_SHA256

COPY patches/ /tmp/php-security-patches/

# A profile without a patch uses the official base unchanged. A patched profile
# rebuilds the exact source and configure options bundled in that base image.
RUN set -eux; \
	if [ -z "$PHP_SECURITY_PATCH_FILE" ]; then \
		[ -z "$PHP_REBUILD_COMPAT_PATCH_FILE" ]; \
		[ -z "$PHP_REBUILD_COMPAT_PATCH_SHA256" ]; \
		rm -rf /tmp/php-security-patches; \
		php --version; \
		exit 0; \
	fi; \
	case "$PHP_SECURITY_PATCH_FILE" in \
		*[!a-zA-Z0-9._-]*) echo "Invalid patch filename: $PHP_SECURITY_PATCH_FILE" >&2; exit 1 ;; \
	esac; \
	[ -n "$PHP_EXPECTED_VERSION" ]; \
	[ -n "$PHP_SECURITY_PATCH_SHA256" ]; \
	[ "$(php-config --version)" = "$PHP_EXPECTED_VERSION" ]; \
	patchPath="/tmp/php-security-patches/$PHP_SECURITY_PATCH_FILE"; \
	[ -f "$patchPath" ]; \
	echo "${PHP_SECURITY_PATCH_SHA256} *${patchPath}" | sha256sum -c -; \
	compatPatchPath=''; \
	if [ -n "$PHP_REBUILD_COMPAT_PATCH_FILE" ]; then \
		case "$PHP_REBUILD_COMPAT_PATCH_FILE" in \
			*[!a-zA-Z0-9._-]*) echo "Invalid compatibility patch filename: $PHP_REBUILD_COMPAT_PATCH_FILE" >&2; exit 1 ;; \
		esac; \
		[ -n "$PHP_REBUILD_COMPAT_PATCH_SHA256" ]; \
		compatPatchPath="/tmp/php-security-patches/$PHP_REBUILD_COMPAT_PATCH_FILE"; \
		[ -f "$compatPatchPath" ]; \
		echo "${PHP_REBUILD_COMPAT_PATCH_SHA256} *${compatPatchPath}" | sha256sum -c -; \
	else \
		[ -z "$PHP_REBUILD_COMPAT_PATCH_SHA256" ]; \
	fi; \
	mkdir -p /usr/local/share/php-security-patches; \
	cp /tmp/php-security-patches/README.md \
		"/usr/local/share/php-security-patches/${PHP_SECURITY_PATCH_FILE%.patch}.md"; \
	apk add --no-cache --virtual .php-core-build-deps \
		$PHPIZE_DEPS \
		argon2-dev \
		coreutils \
		curl-dev \
		gnu-libiconv-dev \
		libsodium-dev \
		libxml2-dev \
		linux-headers \
		oniguruma-dev \
		openssl-dev \
		patch \
		readline-dev \
		sqlite-dev \
	; \
	rm -f /usr/include/iconv.h; \
	ln -sf /usr/include/gnu-libiconv/*.h /usr/include/; \
	export \
		CFLAGS="$PHP_CFLAGS" \
		CPPFLAGS="$PHP_CPPFLAGS" \
		LDFLAGS="$PHP_LDFLAGS" \
	; \
	docker-php-source extract; \
	cd /usr/src/php; \
	if [ -n "$compatPatchPath" ]; then \
		patch --batch --forward --fuzz=0 -p1 < "$compatPatchPath"; \
	fi; \
	patch --batch --forward --fuzz=0 -p1 < "$patchPath"; \
	configureOptions="$(php-config --configure-options)"; \
	./configure $configureOptions; \
	make -j "$(nproc)"; \
	find -type f -name '*.a' -delete; \
	make install; \
	find /usr/local -type f -perm '/0111' -exec sh -euxc 'strip --strip-all "$@" || :' -- '{}' +; \
	make clean; \
	cd /; \
	docker-php-source delete; \
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-cache $runDeps; \
	apk del --no-network .php-core-build-deps; \
	rm -rf /tmp/php-security-patches; \
	pecl update-channels; \
	rm -rf /tmp/pear ~/.pearrc; \
	! { ldd /usr/local/bin/php /usr/local/sbin/php-fpm | grep 'not found'; }; \
	php -r 'if (PHP_VERSION !== $argv[1]) { fwrite(STDERR, "Unexpected PHP version: " . PHP_VERSION . PHP_EOL); exit(1); }' "$PHP_EXPECTED_VERSION"

FROM patched-php

ARG PHP_BASE_IMAGE
ARG PHP_VERSION_SERIES
ARG PHP_EXPECTED_VERSION
ARG PHP_SECURITY_PATCH_FILE
ARG PHP_SECURITY_PATCH_IDS
ARG PHP_SECURITY_PATCH_COMMIT
ARG PHP_SECURITY_PATCH_SHA256
ARG PHP_REBUILD_COMPAT_PATCH_FILE
ARG PHP_REBUILD_COMPAT_PATCH_SHA256
ARG IMAGICK_VERSION=3.6.0
ARG IMAGICK_SHA256=4e2965f2d70dd59a40e7957d56e590e731cad2669e9f89e0fca159d748d2947e
ARG REDIS_VERSION=6.3.0
ARG REDIS_SHA256=0d5141f634bd1db6c1ddcda053d25ecf2c4fc1c395430d534fd3f8d51dd7f0b5
ARG NEWRELIC_PHP_AGENT=10.7.0.319
ARG NEWRELIC_PHP_AGENT_SHA256=64d81d741d0e278d27a5ce96bbc6c8849f7f3fc42a49c81e3795af076e93a7ef
ARG WP_CLI_VERSION=2.12.0
ARG WP_CLI_SHA256=ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c

LABEL org.opencontainers.image.base.name="${PHP_BASE_IMAGE}" \
	org.opencontainers.image.title="PHP WordPress runtime" \
	org.opencontainers.image.description="PHP runtime with optional security backports" \
	com.wp-digital.php.version-series="${PHP_VERSION_SERIES}" \
	com.wp-digital.php.security-patch.ids="${PHP_SECURITY_PATCH_IDS}" \
	com.wp-digital.php.security-patch.commit="${PHP_SECURITY_PATCH_COMMIT}" \
	com.wp-digital.php.security-patch.sha256="${PHP_SECURITY_PATCH_SHA256}" \
	com.wp-digital.php.rebuild-compat-patch.file="${PHP_REBUILD_COMPAT_PATCH_FILE}" \
	com.wp-digital.php.rebuild-compat-patch.sha256="${PHP_REBUILD_COMPAT_PATCH_SHA256}"

# Persistent dependencies.
RUN set -eux; \
	apk add --no-cache \
		bash \
		ghostscript \
		imagemagick \
	;

# Install the PHP extensions required by WordPress, plus Redis, SimpleXML and SOAP.
RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		freetype-dev \
		icu-dev \
		imagemagick-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libwebp-dev \
		libxml2-dev \
		libzip-dev \
	; \
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg \
		--with-webp \
	; \
	docker-php-ext-install -j "$(nproc)" \
		bcmath \
		exif \
		gd \
		intl \
		mysqli \
		simplexml \
		soap \
		zip \
	; \
	curl -fsSL -o /tmp/imagick.tgz "https://pecl.php.net/get/imagick-${IMAGICK_VERSION}.tgz"; \
	echo "${IMAGICK_SHA256} */tmp/imagick.tgz" | sha256sum -c -; \
	pecl install /tmp/imagick.tgz; \
	curl -fsSL -o /tmp/redis.tgz "https://pecl.php.net/get/redis-${REDIS_VERSION}.tgz"; \
	echo "${REDIS_SHA256} */tmp/redis.tgz" | sha256sum -c -; \
	pecl install /tmp/redis.tgz; \
	docker-php-ext-enable imagick redis; \
	rm -rf /tmp/imagick.tgz /tmp/redis.tgz /tmp/pear; \
	out="$(php -r 'exit(0);')"; \
	[ -z "$out" ]; \
	err="$(php -r 'exit(0);' 3>&1 1>&2 2>&3)"; \
	[ -z "$err" ]; \
	extDir="$(php -r 'echo ini_get("extension_dir");')"; \
	[ -d "$extDir" ]; \
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive "$extDir" \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-network --virtual .wordpress-phpexts-rundeps $runDeps; \
	apk del --no-network .build-deps; \
	! { ldd "$extDir"/*.so | grep 'not found'; }; \
	err="$(php --version 3>&1 1>&2 2>&3)"; \
	[ -z "$err" ]

# Recommended PHP.ini settings with project-specific tuning.
RUN set -eux; \
	docker-php-ext-enable opcache; \
	{ \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.validate_timestamps=0'; \
		echo 'opcache.revalidate_freq=0'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
	{ \
		echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
		echo 'display_errors = Off'; \
		echo 'display_startup_errors = Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
		echo 'html_errors = Off'; \
	} > /usr/local/etc/php/conf.d/error-logging.ini; \
	{ \
		echo 'upload_max_filesize = 100M'; \
		echo 'post_max_size = 100M'; \
	} > /usr/local/etc/php/conf.d/uploads.ini

COPY --from=composer-bin /usr/bin/composer /usr/local/bin/composer

# Install WP-CLI from an immutable release and verify the downloaded artifact.
RUN set -eux; \
	curl -fsSL -o /usr/local/bin/wp "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar"; \
	echo "${WP_CLI_SHA256} */usr/local/bin/wp" | sha256sum -c -; \
	chmod +x /usr/local/bin/wp

ENV WP_CLI_ALLOW_ROOT=1

# Install the New Relic agent from a checksummed archive. Its installer expects
# the standard Alpine OpenRC paths even when the base image omits OpenRC itself.
RUN set -eux; \
	if [ "$PHP_VERSION_SERIES" = '8.1' ]; then \
		php -r 'if (version_compare($argv[1], "12.12.0.41", "<")) { fwrite(STDERR, "New Relic PHP agent 12.12.0.41 or newer is required for patched PHP 8.1" . PHP_EOL); exit(1); }' "$NEWRELIC_PHP_AGENT"; \
	fi; \
	apk add --no-cache gcompat; \
	mkdir -p /etc/init.d /etc/conf.d; \
	curl -fsSL -o /tmp/newrelic.tar.gz "https://download.newrelic.com/php_agent/archive/${NEWRELIC_PHP_AGENT}/newrelic-php5-${NEWRELIC_PHP_AGENT}-linux-musl.tar.gz"; \
	echo "${NEWRELIC_PHP_AGENT_SHA256} */tmp/newrelic.tar.gz" | sha256sum -c -; \
	tar -xzf /tmp/newrelic.tar.gz -C /tmp; \
	rm -f /tmp/newrelic.tar.gz; \
	export NR_INSTALL_USE_CP_NOT_LN=1; \
	export NR_INSTALL_SILENT=1; \
	/tmp/newrelic-php5-*/newrelic-install install; \
	rm -rf /tmp/newrelic-php5-*

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Fail the build if the runtime contract changes or an extension cannot load.
RUN set -eux; \
	php -r 'if (strpos(PHP_VERSION, $argv[1] . ".") !== 0) { fwrite(STDERR, "Unexpected PHP version: " . PHP_VERSION . PHP_EOL); exit(1); }' "$PHP_VERSION_SERIES"; \
	if [ -n "$PHP_EXPECTED_VERSION" ]; then \
		php -r 'if (PHP_VERSION !== $argv[1]) { fwrite(STDERR, "Unexpected PHP version: " . PHP_VERSION . PHP_EOL); exit(1); }' "$PHP_EXPECTED_VERSION"; \
	fi; \
	php -m > /tmp/php-modules; \
	for extension in bcmath exif gd imagick intl mysqli newrelic redis SimpleXML soap zip; do \
		grep -Fxq "$extension" /tmp/php-modules; \
	done; \
	grep -Fxq 'Zend OPcache' /tmp/php-modules; \
	composer --version; \
	wp --info; \
	php-fpm -n -tt; \
	if [ -n "$PHP_SECURITY_PATCH_FILE" ]; then \
		test -s "/usr/local/share/php-security-patches/${PHP_SECURITY_PATCH_FILE%.patch}.md"; \
	fi; \
	rm -f /tmp/php-modules

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
