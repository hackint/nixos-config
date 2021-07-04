{ lib, config, ... }:
let
  inherit (lib) types mkOption filter;

  cfg = config.hackint.network;

  isIPv6 = ip: builtins.length (lib.splitString ":" ip) > 2;
in
{
  options.hackint.network = with types; {
    interface = mkOption {
      type = str;
      example = "ens1";
      description = ''
        The name of the WAN-facing interface.
      '';
    };

    addresses = mkOption {
      type = listOf str;
      default = [
        "192.0.2.1/24"
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

    routes = mkOption {
      type = null;
    };
  };
}
