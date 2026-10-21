# PHP security patches

The patches in this directory are vendored because PHP 7.4 is end-of-life and
does not receive new upstream releases. Each patch must have an immutable
upstream commit and a SHA-256 checksum recorded here and in the Dockerfile.

## PHP 7.4.33

- Vulnerabilities: CVE-2026-109618 and CVE-2026-109619
- PHP Security Team commit: `712e60f9edfd03f0960fc4fc3c2c375f42b90aa2`
- Patch file: `php-7.4-cve-2026-109618-109619.patch`
- SHA-256: `4ce7225e512ed559ac92ef9934f00399b1083f5371dc82e1c535bdfa9d74664f`

The Docker build verifies this checksum before applying the patch and fails if
the patch no longer applies cleanly to the pinned PHP source.
