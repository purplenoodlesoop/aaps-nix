{ pkgs, ... }:
{
  flake.output.checks.fmt = pkgs.runCommandLocal "aaps-nix-fmt-check" { } ''
    ${pkgs.nixfmt}/bin/nixfmt --check \
      ${../flake.nix} \
      ${../nix/checks.nix} \
      ${../nix/tasks.nix}
    touch $out
  '';
}
