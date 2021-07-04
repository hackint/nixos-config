let
  pkgs = import ./nix {};

in pkgs.mkShell {
  buildInputs = with pkgs; [
    git
    niv
    morph
  ];
}
