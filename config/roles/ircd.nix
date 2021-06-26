{ config, lib, ... }:
{
  hackint = {
    solanum = {
      enable = true;
      exempts = [
        # TODO: add monitoring
      ];
      opers = {
      };
    };
  };
}
