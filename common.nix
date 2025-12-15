{...}: {
  system.stateVersion = "25.11";
  boot.loader.grub = {
    device = "/dev/vda";
    enable = true;
  };
  networking.useDHCP = true;
  services.openssh.enable = true;
  services.qemuGuest.enable = true;
}
