{ pkgs, ... }:
let
  composition = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "37.0" ];
    buildToolsVersions = [ "36.0.0" ];
    includeEmulator = false;
    includeSystemImages = false;
    includeNDK = false;
  };
in
{
  flake.packages.android-sdk = composition.androidsdk;
}
