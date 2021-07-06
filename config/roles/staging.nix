{ name, nodes, lib, ... }:

{
  networking = {
    domain = "staging.hackint.org";
  };

  deployment.tags = [ "staging" ];

  security.acme.nameserver = lib.head nodes.staging_dns.config.hackint.network.addresses;
  security.acme.tsig.key = "acme:${name}";
  security.acme.tsig.secret = "";
}
