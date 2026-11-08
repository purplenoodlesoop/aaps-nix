{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    core-flake = {
      url = "github:purplenoodlesoop/core-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    aaps-src = {
      url = "github:nightscout/AndroidAPS/4.0.0";
      flake = false;
    };
  };

  outputs =
    { core-flake, aaps-src, ... }:
    with core-flake;
    lib.evalFlake {
      specialArgs = { inherit aaps-src; };

      config = {
        android_sdk.accept_license = true;
        allowUnfreePredicate = pkg: (pkg.meta.homepage or "") == "https://developer.android.com/tools";
      };

      perSystem.imports = with nixosModules; [
        tasks
        ./nix/android-sdk.nix
        ./nix/checks.nix
        ./nix/tasks.nix
      ];
    };
}
