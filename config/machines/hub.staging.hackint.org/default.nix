{
  imports = [
    ./hardware-configuration.nix
    ../../roles/staging.nix
  ];

  networking = {
    hostName = "hub";
  };

  hackint.solanum.sid = "100";

  system.stateVersion = "21.05";
}
