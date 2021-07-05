{ config, nodes, lib, pkgs, ... }:

with lib;

let
  dynamic = rec {
    domain = "dyn.${config.networking.domain}";

    nameservers = config.hackint.dns.master.zones."${domain}".nameservers;

    file = pkgs.writeText "${domain}.zone" ''
      $ORIGIN ${domain}.
      $TTL 60

      @ SOA ${head nameservers} mail.hackint.org 0 200 300 1209600 300

      ${concatMapStringsSep "\n"
        (server: "@ NS ${server}")
        nameservers}
    '';
  };
in
{
  hackint.dns.master = {
    enable = true;

    upstreams = {
      "example" = [ "1.2.3.4" ];
    };

    secrets = mapAttrs'
      (name: node: {
        name = node.config.security.acme.tsig.key;
        value = node.config.security.acme.tsig.secret;
      })
      nodes;

    zones."${dynamic.domain}" = {
      inherit (dynamic) domain file;

      nameservers = [ "ns.example.com" "ns1.example.com" ];
      upstream = "example";

      dynamic.networks = [ "0.0.0.0/0" ];
      dynamic.secrets = mapAttrsToList
        (_: node: node.config.security.acme.tsig.key)
        nodes;
    };
  };
}
