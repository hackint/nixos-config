{
  imports = [
    ./hardware-configuration.nix
    ../../roles/ircd.nix
    ../../roles/staging.nix
  ];

  networking = {
    hostName = "leaf1";
  };

  hackint.network = {
    macAddress = "00:00:00:11:11:12";
    addresses = [
      "192.0.2.3/24"
      "2001:DB8::2/64"
    ];
    gateways = [
      "192.0.2.1"
      "fe80::1"
    ];
  };

  hackint.solanum.sid = "200";

  system.stateVersion = "21.05";
}
