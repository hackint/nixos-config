{ config, ... }:
{
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
        credentialsFile = /etc/nixos/secrets/acme/environment;
        group = "acme";
      };
    };
  };
}

