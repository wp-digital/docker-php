# PHP security patches

The patches in this directory are vendored because these PHP releases are
end-of-life and do not receive new upstream releases. Each patch must have an
immutable upstream source and a SHA-256 checksum recorded here and in the
build profile.

## PHP 7.4.33

- Vulnerabilities: CVE-2026-109618 and CVE-2026-109619
- PHP Security Team commit: `712e60f9edfd03f0960fc4fc3c2c375f42b90aa2`
- Patch file: `php-7.4-cve-2026-109618-109619.patch`
- SHA-256: `4ce7225e512ed559ac92ef9934f00399b1083f5371dc82e1c535bdfa9d74664f`

The Docker build verifies this checksum before applying the patch and fails if
the patch no longer applies cleanly to the pinned PHP source.

## PHP 8.1.34

- Vulnerabilities: CVE-2026-109618 and CVE-2026-109619
- PHP Security Team commit: `1d7dec178a094e6e75b229ce22754045f8c6070a`
- Security patch file: `php-8.1-cve-2026-109618-109619.patch`
- Security patch SHA-256: `2c26157e765e982a872d8456520ec215c5f1516dcbc898477b9a8e9017ed0935`
- Base image: `php:8.1.34-fpm-alpine3.22@sha256:65802aa6e89b89d3378f04913bd3d397dc572325bd6337a75fb8d4fb5e7fe86b`
- Rebuild compatibility patch: `php-8.1-alpine3.22-rebuild-compat.patch`
- Rebuild compatibility patch SHA-256: `a141037dd52ff18cebad0e1c0b96b02ba14919ff57856ced7e253bb4d071272c`

The compatibility patch preserves two fixes applied while building the pinned
official Alpine image but absent from its original PHP source archive:
PHP commits `577b8ae4226368e66fee7a9b5c58f9e2428372fc` (GH-11678) and the
change from `67259e451d`, rebased onto PHP 8.1.34 (GH-14834). It is applied
before the security patch and is not represented as a CVE fix.
