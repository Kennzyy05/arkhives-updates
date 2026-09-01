# Online Updater Bootstrap

ARKhives **7.8.48** is the first build that can download and install future signed updates directly from this GitHub repository.

## One-time bootstrap

Users upgrading from 7.8.47 install the signed 7.8.48 `.arkenpatch` manually through **About & Updates**.

After 7.8.48 is installed, future updates can be delivered through:

**About & Updates → Check for Updates → Download & Install**

Automatic startup checks are enabled by default and can be turned off in the update panel.

## Future publishing flow

For 7.8.49 and later:

1. Build and sign the AMD64 `.arkenpatch`.
2. Create a GitHub Release and upload the signed patch.
3. Put the direct HTTPS release-asset URL and complete patch SHA-256 into `channels/stable.json`.
4. Mirror Stable into `latest.json`.
5. ARKhives 7.8.48+ will discover, download, verify, install, and relaunch.

The private Ed25519 signing key stays offline and is never uploaded here.
