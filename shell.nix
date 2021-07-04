let
  pkgs = import ./nix { };

  pre-commit-hooks = pkgs.nix-pre-commit-hooks.run {
    src = ./.;
    hooks = {
      nixpkgs-fmt.enable = true;
    };
  };

in
pkgs.mkShell {
  buildInputs = with pkgs; [
    git
    niv
    morph
    nixpkgs-fmt
  ];

  inherit (pre-commit-hooks) shellHook;
}
