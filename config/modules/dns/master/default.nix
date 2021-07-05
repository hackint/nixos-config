{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hackint.dns.master;

  zone = pkgs.writeText "${cfg.zones.dynamic.domain}.zone" ''
    $ORIGIN ${cfg.zones.dynamic.domain}.
    $TTL 60

    @ SOA ${head cfg.nameservers} mail.hackint.org 0 200 300 1209600 300

    ${concatMapStringsSep "\n"
      (server: "@ NS ${server}")
      cfg.nameservers}
  '';

in
{
  options.hackint.dns.master = with types; {
    enable = mkEnableOption "the DNS master";

    secrets = mkOption {
      type = attrsOf str;
      description = ''
        Secret TSIG keys.
      '';
      default = { };
    };

    upstreams = mkOption {
      type = attrsOf (listOf str);
      description = ''
        Remote adrresses of upstream servers.
      '';
      default = { };
    };

    zones = mkOption {
      type = attrsOf (submodule ({ name, ... }: {
        options = {
          domain = mkOption {
            type = str;
            description = ''
              The full domain name of the zone.
            '';
            default = name;
          };

          file = mkOption {
            type = path;
            description = ''
              The zone file.
            '';
          };

          upstream = mkOption {
            type = enum (attrNames cfg.upstreams);
            description = ''
              Upstream servers for this zone.
            '';
          };

          nameservers = mkOption {
            type = listOf str;
            description = ''
              FQDNs of public serving servers.
              The first host is used as the primary nameserver.
            '';
          };

          dynamic = mkOption {
            type = nullOr (submodule {
              options = {
                networks = mkOption {
                  type = listOf str;
                  description = ''
                    Hosts and networks allowed to perform dynamic updates.
                  '';
                };

                secrets = mkOption {
                  type = listOf (enum (attrNames cfg.secrets));
                  description = ''
                    Secret TSIG keys allowed for dynamic updates.
                  '';
                };
              };
            });
            description = ''
              Allow dynamic updates for this zone.
            '';
            default = null;
          };
        };
      }));
      description = ''
        The zones to serve.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Let systemd-resolved not listen on 127.0.0.53:53 to avoid conflicts with
    # kresd listening on wildcard.
    services.resolved.extraConfig = ''
      DNSStubListener=no
    '';

    services.knot = {
      enable = true;

      extraConfig =
        let
          concatList = concatMapStringsSep "," (e: ''"${e}"'');
        in
        ''
          server:
            listen: [ "0.0.0.0@53", "::@53" ]

          key:
          ${concatStringsSep "\n" (mapAttrsToList (name: secret: ''
            - id: "${name}"
              algorithm: hmac-sha512
              secret: "${secret}"
          '') cfg.secrets)}

          remote:
          ${concatStringsSep "\n" (mapAttrsToList (name: servers: ''
            - id: "${name}"
              address: [${concatMapStringsSep "," (s: "\"${s}@53\"") servers}]
          '') cfg.upstreams)}

          acl:
          ${concatStringsSep "\n" (mapAttrsToList (name: zone: ''
            - id: "upstream:${name}"
              address: [${concatList cfg.upstreams."${zone.upstream}"}]
              action: transfer
          '') cfg.zones)}

          ${concatStringsSep "\n" (mapAttrsToList (name: zone: ''
            - id: "update:${name}"
              address: [${concatList zone.dynamic.networks}]
              action: update
              update-type: TXT
              key: [ ${concatList zone.dynamic.secrets} ]
          '') (filterAttrs (_: zone: zone.dynamic != null) cfg.zones))}

          policy:
            - id: "default"
              algorithm: ed25519
              cds-cdnskey-publish: always

          template:
            - id: default
              semantic-checks: true
              zonefile-sync: -1
              zonefile-load: difference-no-serial
              serial-policy: dateserial
              journal-content: all
              dnssec-signing: on
              dnssec-policy: default

          zone:
          ${concatStringsSep "\n" (mapAttrsToList (name: zone: ''
            - domain: "${zone.domain}"
              file: "${zone.file}"
              notify: "${zone.upstream}"
              acl: [ ${concatList (
                (singleton "upstream:${name}") ++
                (optional (zone.dynamic != null) "update:${name}")
              )} ]
          '') cfg.zones)}
        '';
    };
  };
}
