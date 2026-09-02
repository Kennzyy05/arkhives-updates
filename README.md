# ARKhives Updates

Public update-feed repository for the ARKhives Windows desktop application.

## Purpose

This repository publishes update metadata for ARKhives. The application checks the JSON feed over HTTPS, downloads the referenced signed .arkenpatch, validates it with the Ed25519 public key already embedded in ARKhives, then installs and relaunches.

## Channels

- Stable: channels/stable.json
- Preview: channels/preview.json
- Convenience alias: latest.json

## Security

The private Ed25519 signing key must NEVER be committed to this repository, attached to a release, included in a source archive, or embedded in the application.

Trust is decided locally by ARKhives. A downloaded update is installed only after the existing patch validator confirms its signature, manifest, architecture, minimum version, and payload hash.

## Publishing a release

Publishing is now automated with scripts/publish_update.ps1.

After a new .arkenpatch has been built, signed, and validated locally, run the publisher once. It reads the patch manifest, calculates SHA-256, creates the GitHub Release, uploads the patch, verifies the uploaded asset, and updates the correct feed files.

See PUBLISH_AUTOMATION.md for the one-time setup and command examples.

The publisher never reads or uploads the private signing key.
