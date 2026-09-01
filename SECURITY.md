# Security Policy

## Update signing key

The ARKhives private Ed25519 update-signing key is confidential and must remain outside GitHub.

Do not commit or upload:
- private signing keys
- signing-key backups
- recovery phrases or passwords
- unencrypted credential bundles

Only the public verification key belongs in the application.

## Update verification

Every downloaded ARKhives update must be rejected unless the existing local updater validates:
1. Ed25519 publisher signature
2. patch manifest
3. target version
4. minimum installed version
5. architecture
6. payload SHA-256

A GitHub-hosted file is not trusted merely because it came from this repository.
