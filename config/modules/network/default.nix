{ lib, config, ... }:
let
  inherit (lib) types mkOption filter;

  cfg = config.hackint.network;

  isIPv6 = ip: builtins.length (lib.splitString ":" ip) > 2;
in
{
  options.hackint.network = with types; {
    interfaceName = mkOption {
      type = str;
      default = "wan";
      readOnly = true;
      description = ''
        The interface name of the WAN-facing interface.
      '';
    };

    macAddress = mkOption {
      type = str;
      example = "00:11:22:33:44:55";
      description = ''
        The MAC Address of the WAN-facing interface.
      '';
    };

    addresses = mkOption {
      type = listOf str;
      example = [
        "192.0.2.2/24"
        "2001:DB8::1/64"
      ];
      description = ''
        List of globally reachable IP addresses with subnet mask.
      '';
    };

    addresses4 = mkOption {
      default = filter (addr: !(isIPv6 addr)) cfg.addresses;
      readOnly = true;
      description = ''
        List of globally reachable IPv4 addresses.
      '';
    };

    addresses6 = mkOption {
      default = filter isIPv6 cfg.addresses;
      readOnly = true;
      description = ''
        List of globally reachable IPv6 addresses.
      '';
    };

    gateways = mkOption {
      type = listOf str;
      example = [
        "192.0.2.1"
        "fe80::1"
      ];
      description = ''
        List of default gateway addresses.
      '';
    };
  };

  config = {
    networking.useNetworkd = true;

    # rename interface to wan
    systemd.network.links."10-${cfg.interfaceName}" = {
      matchConfig.MACAddress = cfg.macAddress;
      linkConfig.Name = cfg.interfaceName;
    };

    # configure addressing and routing
    systemd.network.networks."20-${cfg.interfaceName}" = {
      matchConfig.Name = cfg.interfaceName;
      linkConfig.RequiredForOnline = "routable";
      address = cfg.addresses;
      gateway = cfg.gateways;
    };
  };
}
