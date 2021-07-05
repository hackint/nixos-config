{ config, lib, pkgs, ... }:

with lib;

{
  options = with types; {
    security.acme = {
      nameserver = mkOption {
        type = str;
        description = ''
          Nameserver to push RFC2136 updates to.
        '';
      };
      tsig.key = mkOption {
        type = str;
        description = ''
          Name of the secret key as defined in DNS server configuration.
        '';
      };
      tsig.secret = mkOption {
        type = str;
        description = ''
          Secret key payload.
        '';
      };
    };
  };

  config = {
    users.groups.acme = { };

    security.acme = {
      email = "mail@hackint.org";
      acceptTerms = true;
      certs = {
        "${config.networking.fqdn}" = {
          extraDomainNames = [
            "hackint.org"
            "irc.hackint.org"
          ];
          dnsProvider = "rfc2136";
          credentialsFile = pkgs.writeText "acme-credentials" (with config.security.acme; ''
            LEGO_EXPERIMENTAL_CNAME_SUPPORT=true
            RFC2136_NAMESERVER=${nameserver}
            RFC2136_TSIG_ALGORITHM=hmac-sha512.
            RFC2136_TSIG_KEY=${tsig.key}
            RFC2136_TSIG_SECRET=${tsig.secret}
            RFC2136_PROPAGATION_TIMEOUT=3600
            RFC2136_SEQUENCE_INTERVAL=60
          '');
          group = "acme";
        };
      };
    };
  };
}

