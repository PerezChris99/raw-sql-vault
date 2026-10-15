# Security Policy

## Scope
Raw SQL Vault is a learning/reference repository, not a hosted production service. Reports may concern SQL injection patterns, privilege errors, RLS bypasses, unsafe routines, sensitive data, credentials, or misleading security guidance. No package is production-secure solely because it exists.

## Reporting
Do not disclose credentials, personal data, exploit details, or sensitive evidence in a public issue. Use GitHub private vulnerability reporting if enabled. If unavailable, contact the repository owner through an appropriate private channel and provide only minimum non-sensitive details.

Where safe, include affected path/commit, impact and preconditions, minimal reproduction steps, engine/version, and suggested mitigation. Never include live secrets, production dumps, or third-party records.

## Response expectations
This is a maintainer-managed project, not a staffed response service. Acknowledgement and remediation timelines are not guaranteed. The maintainer will assess severity, attempt safe reproduction, coordinate fixes where feasible, and avoid exposing sensitive details.

## Exposed credentials
Revoke or rotate immediately, investigate use, and assess history remediation. Removing a secret from the latest file does not undo exposure in earlier commits.

## Limitations
The repository provides no security certification and cannot guarantee all vulnerabilities are known. Static scans and individual test passes do not prove universal security. See [the threat model](docs/SECURITY_AND_THREAT_MODEL.md).
