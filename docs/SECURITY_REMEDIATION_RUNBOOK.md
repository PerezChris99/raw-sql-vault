# Credential and RBAC Remediation Runbook

## Why this exists

An earlier revision of the shared role bootstrap created LOGIN roles using the published password literal CHANGE_IN_PRODUCTION. If that revision was executed against any database, the password may have become a real credential. Removing the literal from source does not rotate an existing PostgreSQL role password.

## Immediate response if the old script was executed

1. Identify each affected environment and role: app_service, app_readonly, security_user, and backup_service.
2. Confirm an accountable DBA and application owner before changing production credentials.
3. Create new strong credentials in the approved secret manager and update the application/pooler configuration.
4. Test connectivity with the new secret using a controlled canary or maintenance window.
5. Rotate the role credential or set it to NULL if password authentication should be disabled until provisioning. A NULL password prevents password-based login and can cause downtime if done before clients are updated.
6. Invalidate stale sessions where policy requires it, review connection/audit logs for suspicious access, and assess the reachable Git history for other secrets.
7. Verify role memberships, grants, ownership, RLS policies, and service recovery after rotation.
8. Record environment, roles changed, rotation time, verification evidence, and any incident follow-up without recording secret values.

## Safe bootstrap behaviour

The current bootstrap creates missing LOGIN roles without embedding a password. That means password-authenticated connections will not work until credentials are provisioned out of band. This is intentional fail-closed behaviour, not an automatic credential provisioning mechanism.

The bootstrap should not drop roles, reassign ownership, or delete grants during routine reruns. Schema/role migrations that alter ownership or revoke privileges must be separate, reviewed, backed up, and tested against a disposable clone first.

## Plain language and technical interpretation

**Plain language:** a password printed in a public script is no longer a secret. Removing it from the latest version does not change the password on a database that already used it.

**Technical:** role credential rotation has deployment-specific operational effects. Execute credential changes through a controlled DBA workflow with secret rotation, connection verification, and rollback planning. Never commit the new secret.
