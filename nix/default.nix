{ system ? builtins.currentSystem, config ? { }, release ? "nixpkgs-unstable" }:
let
  sources = import ./sources.nix { };
  overlays = import ./overlays.nix sources;
in
import sources.${release} {
  inherit overlays config;
}
