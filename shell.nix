let
  sources = import ./nix/sources.nix {};

  pkgs = import sources."nixpkgs-unstable" {};

in pkgs.mkShell {
  buildInputs = with pkgs; [
    git
    (callPackage sources.morph {})
    niv
  ];
}
