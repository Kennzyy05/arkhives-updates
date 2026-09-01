# ARKhives Update Feed Contract

ARKhives consumes a small JSON document over HTTPS.

## Fields

- `schema`: feed schema version.
- `channel`: `stable` or `preview`.
- `available`: whether a downloadable update is currently published.
- `version`: target ARKhives version.
- `minimum_version`: minimum installed version accepted by the patch.
- `architecture`: currently `amd64`.
- `patch_url`: direct HTTPS URL to the signed `.arkenpatch`.
- `release_page`: human-readable GitHub Release page.
- `sha256`: SHA-256 of the complete `.arkenpatch` file for transport/integrity diagnostics.
- `notes`: short release summary shown in the application.

## Security boundary

The feed is discovery metadata, not a trust root.

ARKhives MUST still run the downloaded file through its existing signed-patch validator before installation. A valid feed entry must never bypass Ed25519 verification or the patch manifest checks.
