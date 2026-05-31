{ pkgs, lib, config, inputs, ... }: {

  imports = [
    ./hardware-configuration.nix
    ./bash_configuration.nix
    ../config/themes/stylix.nix
  ];

  # --- BOOT & KERNEL ---
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 0;
    };
    
    plymouth = {
      enable = true;
      theme = lib.mkForce "rings_2";
      themePackages = with pkgs; [
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "rings_2" ];
        })
      ];
    };

    supportedFilesystems = [ "fuse" ];
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "v4l2loopback" "tun" "amneziawg" ];
    extraModulePackages = [
      config.boot.kernelPackages.v4l2loopback
      config.boot.kernelPackages.amneziawg
    ];
    bootspec.enable = true;
    binfmt.emulatedSystems = [ "aarch64-linux" ];
    
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };

  # --- NVIDIA ---
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.deviceSection = ''
    Driver "nvidia"
  '';
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  environment.variables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
  };

  # --- WINDOW MANAGER & LOGIN ---
  services.xserver.enable = true;
  services.xserver.windowManager.bspwm.enable = true;
  services.xserver.displayManager.startx.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "startx ${pkgs.bspwm}/bin/bspwm -- vt1";
        user = "mihai";
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd \"startx ${pkgs.bspwm}/bin/bspwm -- vt1\"";
        user = "greeter";
      };
    };
  };

  # --- XDG PORTAL ---
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };
 
  programs.nix-ld.enable = true;

  systemd.services.NetworkManager-wait-online.enable = false;

  # --- NETWORKING & SYSTEM ---
  networking.hostName = "nixos-mihai";
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";
  time.timeZone = "Europe/Moscow";

  systemd.services.awg-wg0 = {
    description = "AmneziaWG tunnel wg0";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.amneziawg-tools}/bin/awg-quick up /etc/amnezia/wg0.conf";
      ExecStop = "${pkgs.amneziawg-tools}/bin/awg-quick down /etc/amnezia/wg0.conf";
    };
  };

  systemd.network.wait-online.enable = true;
  
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 5900 ];
    allowedUDPPorts = [ 41641 51820 ];
    trustedInterfaces = [ "wg0" "tailscale0" ];
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "mihai" ];
  };

  users.users.mihai = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "dialout" ];
  };

  # --- SERVICES ---
  services.openssh.enable = true;
  services.tailscale.enable = true;
  services.flatpak.enable = true;
  services.system76-scheduler.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  services.hardware.openrgb.enable = true;

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "true";
      DNSOverHTTPS = "yes";
      FallbackDNS = [ "1.1.1.1" "8.8.8.8" ];
    };
  };

  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:alt_shift_toggle";
  };
  console.keyMap = "ru";

  hardware.bluetooth.enable = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # --- PACKAGES ---
  environment.systemPackages = with pkgs; [
    inputs.prismlauncher-cracked.packages.${pkgs.stdenv.hostPlatform.system}.prismlauncher
    picom
    p7zip
    git
    wget
    curl
    jq
    xclip
    maim
    firefox
    discord
    vesktop
    alacritty
    bspwm
    sxhkd
    dmenu
    telegram-desktop
    ffmpeg
    unrar
    zip
    unzip
    flatpak
    steam
    mpv
    xclicker
    nvidia-vaapi-driver
    nvtopPackages.nvidia
    python3
    android-tools
    xinit
    rofi
    gruvbox-plus-icons
    feh
    x11vnc
    polybarFull
    pavucontrol
    amneziawg-tools
  ];

  # --- PROGRAMS ---
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  programs.fuse.userAllowOther = true;

  # --- SYSTEMD SERVICES ---
  systemd.services.x11vnc = {
    description = "x11vnc server";
    after = [ "graphical.target" ];
    wantedBy = [ "graphical.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.x11vnc}/bin/x11vnc -display :0 -auth /home/mihai/.Xauthority -rfbport 5900 -forever -shared -nopw";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "mihai";
      Environment = "PATH=${pkgs.gawk}/bin:${pkgs.nettools}/bin";
    };
  };

  # --- USER SERVICES ---
  systemd.user.services.audiosource = {
    description = "Android Phone Microphone";
    wantedBy = [ "default.target" ];
    path = with pkgs; [ android-tools pulseaudio python3 bash ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash /home/mihai/audiosource run";
      Restart = "always";
    };
  };
}
