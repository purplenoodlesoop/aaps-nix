{ pkgs, aaps-src, ... }:
let
  git = "${pkgs.git}/bin/git";
  apksigner = "${pkgs.apksigner}/bin/apksigner";
  remote = "https://github.com/nightscout/AndroidAPS.git";
in
{
  tasks = {
    build = {
      description = "Build the pinned AAPS as an unsigned full release APK into out/";
      body = ''
        set -euo pipefail
        root="$(${git} rev-parse --show-toplevel)"

        if [ -z "''${ANDROID_HOME:-}" ]; then
          echo "ANDROID_HOME must point at an Android SDK" >&2
          exit 2
        fi

        rev="${aaps-src.rev}"
        work="''${AAPS_WORKDIR:-''${XDG_CACHE_HOME:-$HOME/.cache}/aaps-nix/AndroidAPS}"

        if [ ! -d "$work/.git" ]; then
          mkdir -p "$work"
          ${git} -C "$work" init -q
          ${git} -C "$work" remote add origin "${remote}"
        fi

        tag="$(${git} ls-remote --tags "${remote}" \
          | ${pkgs.gawk}/bin/awk -v rev="$rev" '$1 == rev { sub("refs/tags/", "", $2); sub(/\^\{\}$/, "", $2); print $2; exit }')"

        echo "==> fetching $rev''${tag:+ ($tag)}"
        if [ -n "$tag" ]; then
          ${git} -C "$work" fetch -q --depth 1 origin "+refs/tags/$tag:refs/tags/$tag"
        else
          ${git} -C "$work" fetch -q --depth 1 origin "$rev"
        fi
        ${git} -C "$work" checkout -q --detach "$rev"

        if [ "$(${git} -C "$work" rev-parse HEAD)" != "$rev" ]; then
          echo "checkout is not at the pinned revision $rev" >&2
          exit 1
        fi
        if [ -n "$(${git} -C "$work" status --porcelain --untracked-files=no)" ]; then
          echo "$work has local changes; AAPS refuses to build a release from a dirty tree" >&2
          exit 1
        fi

        cpus="$(getconf _NPROCESSORS_ONLN)"
        workers="''${AAPS_GRADLE_WORKERS:-$(( cpus > 1 ? cpus / 2 : 1 ))}"

        export JAVA_HOME="${pkgs.temurin-bin-21.home}"
        export PATH="$JAVA_HOME/bin:${pkgs.git}/bin:$PATH"

        echo "==> building with $workers Gradle workers"
        (cd "$work" && ./gradlew --max-workers "$workers" clean :app:assembleFullRelease)

        name="''${tag:-''${rev:0:7}}"
        mkdir -p "$root/out"
        apk="$root/out/aaps-$name-unsigned.apk"
        cp "$work/app/build/outputs/apk/full/release/app-full-release-unsigned.apk" "$apk"
        echo "$apk"
      '';
    };

    sign = {
      description = "Sign an unsigned APK with APK Signature Scheme v3: sign <keystore> <alias> <unsigned.apk>";
      body = ''
        set -euo pipefail

        if [ "$#" -ne 3 ]; then
          echo "usage: nix run .#sign -- <keystore> <alias> <unsigned.apk>" >&2
          exit 2
        fi
        keystore="$1"
        key_alias="$2"
        unsigned="$3"
        signed="''${unsigned%-unsigned.apk}.apk"

        if [ "$signed" = "$unsigned" ]; then
          echo "expected a file ending in -unsigned.apk" >&2
          exit 2
        fi

        ${apksigner} sign \
          --ks "$keystore" \
          --ks-key-alias "$key_alias" \
          --v1-signing-enabled false \
          --v2-signing-enabled false \
          --v3-signing-enabled true \
          --v4-signing-enabled false \
          --out "$signed" \
          "$unsigned"

        ${apksigner} verify --print-certs "$signed"
        echo "$signed"
      '';
    };

    verify = {
      description = "Check that a signed APK carries the expected certificate: verify <sha256> <signed.apk>";
      body = ''
        set -euo pipefail

        if [ "$#" -ne 2 ]; then
          echo "usage: nix run .#verify -- <certificate sha256> <signed.apk>" >&2
          exit 2
        fi
        expected="$(printf '%s' "$1" | tr -d ': ' | tr '[:upper:]' '[:lower:]')"
        apk="$2"

        got="$(${apksigner} verify --print-certs "$apk" \
          | ${pkgs.gawk}/bin/awk -F': ' '/certificate SHA-256 digest/ { print $2; exit }')"

        if [ "$got" != "$expected" ]; then
          echo "certificate mismatch" >&2
          echo "  expected $expected" >&2
          echo "  got      $got" >&2
          exit 1
        fi
        echo "certificate matches: $got"
      '';
    };

    update = {
      description = "Re-pin AAPS to a tag or commit: update <ref>";
      body = ''
        set -euo pipefail
        cd "$(${git} rev-parse --show-toplevel)"

        ref="''${1:-}"
        if [ -z "$ref" ]; then
          echo "usage: nix run .#update -- <tag or commit>   (e.g. 4.0.1)" >&2
          exit 2
        fi

        ${pkgs.gnused}/bin/sed -i \
          "s|url = \"github:nightscout/AndroidAPS/.*\";|url = \"github:nightscout/AndroidAPS/$ref\";|" \
          flake.nix
        ${pkgs.nix}/bin/nix flake update aaps-src
        echo "pinned to $ref - review the diff and commit"
      '';
    };

    fmt = {
      description = "Format every Nix file in the tree";
      body = ''
        set -euo pipefail
        cd "$(${git} rev-parse --show-toplevel)"
        ${pkgs.nixfmt}/bin/nixfmt flake.nix nix/*.nix
      '';
    };
  };
}
