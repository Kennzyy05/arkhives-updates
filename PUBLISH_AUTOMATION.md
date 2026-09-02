# ARKhives one-command publishing

The repository now includes scripts/publish_update.ps1.

This removes the manual GitHub steps for normal future releases. After a new .arkenpatch has already been built, signed, and validated locally, the publisher can create the GitHub Release, upload the patch, verify its SHA-256, and update the feed automatically.

## One-time Windows setup

Install GitHub CLI, then authenticate once:

    gh auth login

Choose GitHub.com, HTTPS, and browser authentication.

The publisher never signs updates and never reads the private Ed25519 signing key. Keep the signing key local and outside this repository.

## Publish a stable update

Example:

    powershell -ExecutionPolicy Bypass -File .\scripts\publish_update.ps1 -PatchPath "C:\path\ARKhives_v7.8.55_AMD64.arkenpatch" -Notes "ARKhives v7.8.55 update."

The script reads manifest.json inside the .arkenpatch and automatically gets the target version, minimum version, and architecture.

It then:
1. calculates the complete patch SHA-256;
2. creates the matching GitHub Release tag;
3. uploads only the supplied .arkenpatch;
4. verifies the uploaded GitHub asset digest;
5. generates the feed JSON;
6. updates channels/stable.json;
7. updates latest.json.

If release creation or asset verification fails, the feeds are not changed.

## Preview channel

Example:

    powershell -ExecutionPolicy Bypass -File .\scripts\publish_update.ps1 -PatchPath "C:\path\update.arkenpatch" -Channel preview -Notes "Preview update."

Preview publishing updates only channels/preview.json.

## Safety rules

- Never give the publisher the private signing key.
- Never commit signing-key material.
- Never rename an old patch to a newer version.
- Build, sign, and validate locally before publishing.
- The publisher refuses to overwrite an existing release tag automatically.
