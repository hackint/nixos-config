{
  imports = [
    ./hardware-configuration.nix
    ../../roles/ircd.nix
    ../../roles/staging.nix
  ];

  networking = {
    hostName = "hub";
  };

  hackint.solanum.sid = "100";

  system.stateVersion = "21.05";
}
