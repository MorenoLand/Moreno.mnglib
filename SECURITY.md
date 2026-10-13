# Security policy

MNG files are untrusted input. Implementations should reject truncated chunks, impossible chunk lengths, incomplete PNG frames, and arithmetic that would exceed the host language's safe bounds.

## Reporting a vulnerability

Please use [GitHub's private vulnerability reporting form](https://github.com/MorenoLand/Moreno.mnglib/security/advisories/new) when available. Include the affected language folder, compiler or runtime version, a minimized input if possible, and the observed impact.

Do not publish an exploitable input in a public issue before maintainers have had a reasonable opportunity to investigate it. If private reporting is unavailable, open a public issue without attaching the exploit and request a private contact path.

This is a reference project, not a hosted service. There is no guaranteed response time or supported-version SLA; fixes should be made against the latest repository state and shared fixtures should be added when appropriate.
