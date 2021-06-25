{
  imports = [
    ./hardware-configuration.nix
    ../../roles/staging.nix
  ];

  networking = {
    hostName = "leaf1";
  };

  hackint.solanum.sid = "200";

  system.stateVersion = "21.05";
}
