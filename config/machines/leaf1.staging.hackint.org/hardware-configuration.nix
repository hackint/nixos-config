{

  boot.loader.systemd-boot.enable = true;

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };
}
