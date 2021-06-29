{ config, lib, ... }:
{
  hackint = {
    solanum = {
      enable = true;
      isHub = lib.mkDefault false;
      exempts = [
        # TODO: add monitoring
      ];
      opers = {
      };
      classes = {
        server = {
          pingTime = "5 minutes";
          autoconnFreq = "1 minute";
          maxConnections = 16;
          maxAutoconn = if config.hackint.solanum.isHub then 0 else 1;
          sendQ = "2 megabytes";
        };
      };
    };
  };
}
