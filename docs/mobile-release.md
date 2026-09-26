# Mobile APK release operations

The workflow is `.github/workflows/android-release.yml`. A push to `main` builds and retains a signed APK artifact only; it **never deploys**. The APK is named `pkgenerus-<versionName>-<versionCode>.apk` and uses `PKG_API_BASE=https://pkgenerus.my.id`.

## Prepare a release

1. Update `version:` in `pubspec.yaml` using `versionName+versionCode` syntax, for example `1.5.1+16`. Keep application ID `id.pkgenerus.pkgenerus_app`. The workflow rejects version codes at or below the currently released code 15; each release code must increase.
2. Continue using the established production signing keystore. Never commit or replace it casually. If a signing key must be rotated, coordinate the Android distribution/update process first and update the GitHub secrets through an approved procedure.
3. Merge/push to `main`. Download and test the artifact from the successful **Android release APK** workflow run. This is artifact-only.

Required signing secret names:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

## Explicit production deployment

After artifact review and approval, manually run **Android release APK** from GitHub Actions (`workflow_dispatch`) and explicitly set `deploy_production` to `true`. Deployment is additionally protected by the GitHub `production` environment; configure required reviewers/approval there. Leaving the input false only builds an artifact.

Deployment secret names:

- `DEPLOY_HOST`
- `DEPLOY_USER`
- `DEPLOY_SSH_KEY`
- `DEPLOY_KNOWN_HOSTS` (base64-encoded known_hosts content)
- `DEPLOY_PORT`

Provision these with approved values; do not guess them. The account must be non-root, host-key verification remains strict, and it needs only the minimum write/rename permissions in:

`/var/www/pkgenerus.my.id/shared/storage/app/private/app-releases/`

The server needs `sh`, `sha256sum`, and `unzip`, but **does not need Flutter or the Android SDK**. Server/user/key/package installation and permissions are operational prerequisites and are not changed by this workflow.

## Verification and rollback

Deployment uploads a uniquely named temporary file, compares byte size and SHA-256, tests the ZIP/APK, copies an existing same-name final APK to a UTC timestamped `.backup-*` file, then atomically renames the verified temporary file. A failed deployment removes only its temporary upload and does not delete the active APK.

For rollback, an authorized operator should verify the selected backup's checksum and APK validity, preserve the current file, and atomically rename/copy the approved backup to the filename consumed by the application. Follow production change approval; the workflow intentionally performs no automatic rollback or server reconfiguration.
