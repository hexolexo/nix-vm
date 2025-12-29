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
    hostName = "amnestic-vm";
    networkmanager.enable = true;
    firewall.enable = false;
  };
  services.xserver.desktopManager.cinnamon.enable = true;
  services.cinnamon.apps.enable = true;
  services.displayManager.sddm.enable = true;
  services.xserver.enable = true;

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

  users.users.amnestic = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video" "audio"];
    password = "forgetful";
  };
  home-manager.users.amnestic = {
    pkgs,
    config,
    ...
  }: {
    home.stateVersion = "25.11";
    programs.firefox = {
      enable = true;
      profiles.default = {
        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
        ];
      };
    };
    programs.librewolf = {
      enable = true;
      settings = {
        # I2P proxy settings
        "network.proxy.type" = 1; # Manual proxy
        "network.proxy.http" = "192.168.100.1";
        "network.proxy.http_port" = 4444;
        "network.proxy.ssl" = "192.168.100.1";
        "network.proxy.ssl_port" = 4444;
        "network.proxy.no_proxies_on" = "localhost, 127.0.0.1, 192.168.100.1";

        # Allow .i2p domains to resolve
        "network.dns.blockDotOnion" = false;

        #  NOTE: Disables WebRTC to prevent IP leaks
        "media.peerconnection.enabled" = false;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    tor-browser
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
    user = "amnestic";
  };
}
