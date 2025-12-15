{
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  system.stateVersion = "25.11";

  boot.loader.grub = {
    device = "/dev/vda";
    enable = true;
  };

  networking = {
    hostName = "nixos-desktop";
    networkmanager.enable = true;
    firewall.enable = false;
  };
  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    displayManager.lightdm.enable = true;
    xkb = {
      layout = "us,us";
      variant = ",colemak";
      options = "grp:alt_shift_toggle";
    };
  };
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      X11Forwarding = false;
    };
  };

  users.users.root.password = "nixos";

  users.users.desktop = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video" "audio"];
    password = "desktop";
  };

  environment.systemPackages = with pkgs; [
    vim
    firefox
    htop
    curl
    git
  ];

  services.qemuGuest.enable = true;

  # SPICE guest tools for better VM integration (clipboard sharing, etc)
  services.spice-vdagentd.enable = true;

  # Auto-login for VM convenience (remove for prod)
  services.displayManager.autoLogin = {
    enable = true;
    user = "desktop";
  };

  # HACK: GNOME needs this to avoid autologin issues
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
}
