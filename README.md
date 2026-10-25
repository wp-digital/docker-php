# PHP container

This repository uses one Dockerfile and one publishing workflow for multiple
PHP version series. The base image, exact expected version, and optional
security patch are build arguments resolved by the workflow.

## Build profiles

| PHP series | Base image | Security patch | Status |
| --- | --- | --- | --- |
| 7.4 | Pinned PHP 7.4.33 Alpine 3.16 digest | CVE-2026-109618 and CVE-2026-109619 | Released and rollout-tested |
| 8.1 | Pinned PHP 8.1.34 Alpine 3.22 digest | CVE-2026-109618 and CVE-2026-109619 | Configured for build testing |
| 8.2 | Pinned PHP 8.2.35 Alpine 3.24 digest | None; fixed in the official upstream release | Configured for release |
| Other | `php:<version>-fpm-alpine` | None | Generic compatibility path; not yet tested by this change |

PHP 7.4 is end-of-life, so its profile rebuilds PHP 7.4.33 from the source
bundled in the pinned official image and applies the PHP Security Team
backport. The resulting PHP version remains `7.4.33`; scanners that only
compare version numbers may therefore report a false positive. Patch
provenance is recorded in `patches/README.md` and in the image labels. The PHP
8.1 profile follows the same model and additionally reapplies compatibility
fixes used by the official Alpine 3.22 build before rebuilding PHP.

The PHP 8.2 profile uses the official PHP 8.2.35 security release, where the
fixes are already included upstream. It pins the Alpine 3.24 image digest and
does not rebuild PHP or apply a repository-owned security patch.

An unpatched profile skips the PHP core rebuild and continues from the selected
official PHP base. Adding another patched profile requires adding its patch and
an explicit branch to the `Resolve PHP build profile` workflow step. The shared
Dockerfile itself does not need to be duplicated.

## Local PHP 7.4 build

The Dockerfile defaults represent the patched PHP 7.4 profile. Build and load
the production Linux AMD64 target with:

```sh
docker buildx build \
  --platform linux/amd64 \
  --pull \
  --load \
  --tag docker-php/php-7.4-newrelic-10.7.0.319:local \
  .
```

The Dockerfile performs build-time checks for the selected PHP version series,
the exact version when configured, required extensions, Composer, WP-CLI,
PHP-FPM, New Relic, and patch provenance.

Additional host-side smoke checks:

```sh
sh scripts/smoke-test.sh docker-php/php-7.4-newrelic-10.7.0.319:local
```

## Local PHP 8.1 build

Build and load the pinned PHP 8.1 profile with:

```sh
docker buildx build \
  --platform linux/amd64 \
  --pull \
  --load \
  --build-arg PHP_BASE_IMAGE=php:8.1.34-fpm-alpine3.22@sha256:65802aa6e89b89d3378f04913bd3d397dc572325bd6337a75fb8d4fb5e7fe86b \
  --build-arg PHP_VERSION_SERIES=8.1 \
  --build-arg PHP_EXPECTED_VERSION=8.1.34 \
  --build-arg PHP_SECURITY_PATCH_FILE=php-8.1-cve-2026-109618-109619.patch \
  --build-arg PHP_SECURITY_PATCH_IDS=CVE-2026-109618,CVE-2026-109619 \
  --build-arg PHP_SECURITY_PATCH_COMMIT=1d7dec178a094e6e75b229ce22754045f8c6070a \
  --build-arg PHP_SECURITY_PATCH_SHA256=2c26157e765e982a872d8456520ec215c5f1516dcbc898477b9a8e9017ed0935 \
  --build-arg PHP_REBUILD_COMPAT_PATCH_FILE=php-8.1-alpine3.22-rebuild-compat.patch \
  --build-arg PHP_REBUILD_COMPAT_PATCH_SHA256=a141037dd52ff18cebad0e1c0b96b02ba14919ff57856ced7e253bb4d071272c \
  --build-arg NEWRELIC_PHP_AGENT=12.12.0.41 \
  --build-arg NEWRELIC_PHP_AGENT_SHA256=b93a0f11dc9a65ae8ca992dc8edd8db756591eccbdb74308f744840acde4e24f \
  --tag docker-php/php-8.1-newrelic-12.12.0.41:local \
  .
```

The patched PHP 8 error flow requires New Relic 12.12.0.41 or newer. Older
agents, including 10.7.0.319, do not preserve `E_DONT_BAIL` when forwarding
errors to PHP and therefore do not preserve the patched PHP error semantics.
The release-gate smoke test verifies this behavior by requiring an object's
destructor to run after an uncaught exception with New Relic loaded.

Run the same release-gate smoke checks with the 8.1 expectations:

```sh
EXPECTED_PHP_SERIES=8.1 \
EXPECTED_PHP_VERSION=8.1.34 \
EXPECTED_PATCH_COMMIT=1d7dec178a094e6e75b229ce22754045f8c6070a \
SECURITY_PATCH_FILE=php-8.1-cve-2026-109618-109619.patch \
sh scripts/smoke-test.sh docker-php/php-8.1-newrelic-12.12.0.41:local
```

## Local PHP 8.2 build

Build and load the pinned upstream-fixed PHP 8.2 profile with:

```sh
docker buildx build \
  --platform linux/amd64 \
  --pull \
  --load \
  --build-arg PHP_BASE_IMAGE=php:8.2.35-fpm-alpine3.24@sha256:62acd0827698068d9605bf236fb2fc3c0b10052fd98974d7e9b3ab05ae7291ca \
  --build-arg PHP_VERSION_SERIES=8.2 \
  --build-arg PHP_EXPECTED_VERSION=8.2.35 \
  --build-arg PHP_SECURITY_PATCH_FILE= \
  --build-arg PHP_SECURITY_PATCH_IDS= \
  --build-arg PHP_SECURITY_PATCH_COMMIT= \
  --build-arg PHP_SECURITY_PATCH_SHA256= \
  --build-arg PHP_REBUILD_COMPAT_PATCH_FILE= \
  --build-arg PHP_REBUILD_COMPAT_PATCH_SHA256= \
  --build-arg NEWRELIC_PHP_AGENT=12.12.0.41 \
  --build-arg NEWRELIC_PHP_AGENT_SHA256=b93a0f11dc9a65ae8ca992dc8edd8db756591eccbdb74308f744840acde4e24f \
  --tag docker-php/php-8.2-newrelic-12.12.0.41:local \
  .
```

Run the release-gate smoke checks without repository-owned patch expectations:

```sh
EXPECTED_PHP_SERIES=8.2 \
EXPECTED_PHP_VERSION=8.2.35 \
EXPECTED_PATCH_COMMIT= \
SECURITY_PATCH_FILE= \
sh scripts/smoke-test.sh docker-php/php-8.2-newrelic-12.12.0.41:local
```

## Release

Run the `Publish PHP image` workflow and provide:

- PHP major/minor version, such as `7.4`;
- New Relic version and the SHA-256 of its musl archive;
- an immutable release tag.

For the first patched PHP 7.4 release, use:

```text
7.4.33-cve-2026-109618-109619-r1
```

For the first patched PHP 8.1 release, use:

```text
8.1.34-cve-2026-109618-109619-r1
```

For the first upstream-fixed PHP 8.2 release, use:

```text
8.2.35-cve-2026-109618-109619-r1
```

Use New Relic PHP agent `12.12.0.41` with SHA-256
`b93a0f11dc9a65ae8ca992dc8edd8db756591eccbdb74308f744840acde4e24f`
for the PHP 8.x profiles.

The target package name is derived from the inputs:

```text
ghcr.io/wp-digital/docker-php/php-<php-version>-newrelic-<newrelic-version>
```

The workflow refuses to overwrite an existing release tag and also publishes a
commit-specific `sha-...` tag. It deliberately does not publish `latest`.
