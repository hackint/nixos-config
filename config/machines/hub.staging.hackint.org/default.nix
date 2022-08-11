{
  imports = [
    ./hardware-configuration.nix
    ../../roles/ircd.nix
    ../../roles/staging.nix
  ];

  networking = {
    hostName = "hub";
  };

  hackint.network = {
    macAddress = "00:00:00:11:11:11";
    addresses = [
      "192.0.2.2/24"
      "2001:DB8::1/64"
    ];
    gateways = [
      "192.0.2.1"
      "fe80::1"
    ];
  };

  hackint.solanum.sid = "100";

  system.stateVersion = "21.05";
}
