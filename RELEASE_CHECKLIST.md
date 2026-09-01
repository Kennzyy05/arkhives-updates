# Release Publishing Checklist

- [ ] Build Windows AMD64 application.
- [ ] Run regression tests and `go vet`.
- [ ] Sign the `.arkenpatch` using the authorized offline ARKhives signing key.
- [ ] Independently verify the Ed25519 signature.
- [ ] Verify patch payload SHA-256.
- [ ] Verify manifest target version, minimum version, and architecture.
- [ ] Create a GitHub Release named for the target version.
- [ ] Upload the signed `.arkenpatch` release asset.
- [ ] Copy the asset's direct HTTPS download URL into the channel JSON.
- [ ] Add the complete `.arkenpatch` SHA-256 to the feed.
- [ ] Update `latest.json` when publishing Stable.
- [ ] Confirm no private signing material is present.
- [ ] Test ARKhives online check -> download -> validate -> install -> relaunch on Windows.
