# ARKhives Updates

Public update-feed repository for the ARKhives Windows desktop application.

## Purpose

This repository publishes update metadata for ARKhives. The application checks the JSON feed over HTTPS, downloads the referenced signed `.arkenpatch`, validates it with the Ed25519 public key already embedded in ARKhives, then installs and relaunches.

## Channels

- Stable: `channels/stable.json`
- Preview: `channels/preview.json`
- Convenience alias: `latest.json`

## Security

The private Ed25519 signing key must NEVER be committed to this repository, attached to a release, included in a source archive, or embedded in the application.

Trust is decided locally by ARKhives. A downloaded update is installed only after the existing patch validator confirms its signature, manifest, architecture, minimum version, and payload hash.

## Publishing a release

1. Build and sign the new AMD64 `.arkenpatch`.
2. Create a GitHub Release for the version.
3. Upload the signed `.arkenpatch` as a release asset.
4. Update `channels/stable.json` or `channels/preview.json`.
5. Update `latest.json` to mirror the current stable release.
6. Never publish signing-key material.
