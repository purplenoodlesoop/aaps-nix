# aaps-nix

Build, sign and verify [AndroidAPS](https://github.com/nightscout/AndroidAPS)
from a pinned upstream release, with the toolchain supplied by Nix.

This repository carries no AndroidAPS code and publishes no APK. Upstream is
AGPL-3.0 and is fetched at build time; the code here is MIT. Every looper builds
and signs their own app.

## Use

```sh
nix run .#build
nix run .#sign -- ~/aaps.jks aaps out/aaps-4.0.0-unsigned.apk
nix run .#verify -- '<certificate sha256>' out/aaps-4.0.0.apk
```

`build` prints the path of the unsigned APK it produced. `sign` asks for the
keystore password itself and writes the signed APK next to the unsigned one.
`verify` compares the signing certificate against the one you expect, given with
or without colons. Keep that fingerprint somewhere safe: Android installs an
update only over an app signed with the same key, so every future build has to
match it.

`nix run .#tasks-help` lists every task.

## Updating

```sh
nix run .#update -- 4.0.1
```

Moves the pin in `flake.nix` and `flake.lock`. Review the diff and commit.

## What Nix does and does not do

Nix pins the AndroidAPS revision, supplies JDK 21, `git`, `apksigner` and the
Android SDK, and runs every step as a task. No SDK needs to be installed and
`ANDROID_HOME` is ignored.

The SDK is `androidenv` with exactly the platform and build tools the pinned
release asks for (`nix/android-sdk.nix`). It is read-only, so when an update
needs a different version the build fails instead of downloading it; add the
version there. Building the SDK accepts Google's Android SDK licence, and only
packages from `androidenv` are allowed as unfree.

Gradle dependencies are not pinned. Pinning the few thousand Maven artifacts
AndroidAPS depends on for an offline sandbox build would cost far more than it
returns, so `build` is a task, not a package, and Gradle downloads them itself.

## Why the build checks out its own clone

The AndroidAPS build refuses to produce a release without `git` or from a tree
with uncommitted changes, and stamps the build with `git describe`. A Nix store
copy of the source has no `.git`, so `build` fetches the pinned revision into a
working clone, checks that it sits exactly at the locked commit and that the tree
is clean, and builds there.

The clone lives in `$XDG_CACHE_HOME/aaps-nix` (`~/.cache/aaps-nix` by default);
set `AAPS_WORKDIR` to move it. Gradle runs with half the machine's cores; set
`AAPS_GRADLE_WORKERS` to change that.

Signing uses APK Signature Scheme v3 only. AndroidAPS requires Android 12, which
makes the older schemes redundant.
