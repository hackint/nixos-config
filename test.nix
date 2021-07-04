let
  pkgs = import ./nix { };
  inherit (pkgs) lib;
  machines = builtins.removeAttrs (import ./config/default.nix) [ "network" ];
  fakeDeploymetModule = {
    options.deployment = lib.mkOption {
      type = lib.types.attrs;
    };
  };

  nixosTest = import (pkgs.path + "/nixos/lib/testing-python.nix") { inherit (pkgs) system; };
in
nixosTest.makeTest {
  nodes = lib.mapAttrs
    (name: machine: {
      imports = [
        machine
        fakeDeploymetModule
        { _module.args.name = name; }
      ];
    })
    machines;
  testScript = "";
}
