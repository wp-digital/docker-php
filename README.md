# PHP container

This repository uses one Dockerfile and one publishing workflow for multiple
PHP version series. The base image, exact expected version, and optional
security patch are build arguments resolved by the workflow.

## Build profiles

| PHP series | Base image | Security patch | Status |
| --- | --- | --- | --- |
| 7.4 | Pinned PHP 7.4.33 Alpine 3.16 digest | CVE-2026-109618 and CVE-2026-109619 | Configured and ready for build testing |
| Other | `php:<version>-fpm-alpine` | None | Generic compatibility path; not yet tested by this change |

PHP 7.4 is end-of-life, so its profile rebuilds PHP 7.4.33 from the source
bundled in the pinned official image and applies the PHP Security Team
backport. The resulting PHP version remains `7.4.33`; scanners that only
compare version numbers may therefore report a false positive. Patch
provenance is recorded in `patches/README.md` and in the image labels.

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

## Release

Run the `Publish PHP image` workflow and provide:

- PHP major/minor version, such as `7.4`;
- New Relic version and the SHA-256 of its musl archive;
- an immutable release tag.

For the first patched PHP 7.4 release, use:

```text
7.4.33-cve-2026-109618-109619-r1
```

The target package name is derived from the inputs:

```text
ghcr.io/wp-digital/docker-php/php-<php-version>-newrelic-<newrelic-version>
```

The workflow refuses to overwrite an existing release tag and also publishes a
commit-specific `sha-...` tag. It deliberately does not publish `latest`.
