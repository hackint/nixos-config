{
  imports = [
    ./hardware-configuration.nix
    ../../roles/staging.nix
    ../../roles/dns.nix
  ];

  networking = {
    hostName = "dns";
  };

  system.stateVersion = "21.05";
}
