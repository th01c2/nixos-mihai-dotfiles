{ pkgs, lib, config, inputs, ... }: {

  imports = [
    ./hardware-configuration.nix
    ./bash_configuration.nix
    ../config/themes/stylix.nix
    ./hyprland.nix
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
    kernelModules = [ "v4l2loopback" "tun" "amneziawg" "uinput" ];
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

  # --- DESKTOP & LOGIN ---
  # KDE Plasma desktop for olesea
  services.desktopManager.plasma6.enable = true;

services.greetd = let
  session-router = pkgs.writeShellScript "session-router" ''
    case "$USER" in
      olesea)
        exec ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland
        ;;
      *)
        exec ${pkgs.hyprland}/bin/Hyprland
        ;;
    esac
  '';
in {
  enable = true;
  settings.default_session = {
    command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --user-menu --cmd ${session-router}";
    user = "greeter";
  };
};

  # --- XDG PORTAL ---
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
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
    allowedTCPPorts = [ 22 5900 47984 47989 47990 48010 ];
    allowedUDPPorts = [ 41641 51820 47998 47999 48000 48002 48010 ];
    trustedInterfaces = [ "wg0" "tailscale0" ];
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "mihai" "olesea" ];
  };

  users.users.mihai = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "dialout" "uinput" "render" ];
    packages = with pkgs; [
      inputs.prismlauncher-cracked.packages.${pkgs.stdenv.hostPlatform.system}.prismlauncher
      alacritty
      gruvbox-plus-icons
      discord
      vesktop
      telegram-desktop
      steam
      mpv
      android-tools
    ];
  };

  users.users.olesea = {
    isNormalUser = true;
    initialPassword = "1234";
    extraGroups = [ "wheel" "networkmanager" "video" ];
    packages = with pkgs; [
      chromium
    ];
  };

  # --- SUNSHINE HOST ---
  services.sunshine = {
    enable = true;
    autoStart = false;
    capSysAdmin = true;
    openFirewall = true;
    package = pkgs.sunshine.override { cudaSupport = true; };
  };
  hardware.uinput.enable = true;

  systemd.services.sunshine = {
    description = "Sunshine server";
    after = [ "graphical.target" ];
    wantedBy = [ "graphical.target" ];
    serviceConfig = {
      ExecStart = "${config.security.wrapperDir}/sunshine";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "mihai";
      Environment = [
        "DISPLAY=:0"
        "XAUTHORITY=/home/mihai/.Xauthority"
      ];
    };
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

  # --- SYSTEM-WIDE PACKAGES (shared by all users) ---
  environment.systemPackages = with pkgs; [
    file-roller
    p7zip
    git
    wget
    curl
    jq
    firefox
    ffmpeg
    unrar
    zip
    unzip
    flatpak
    nvidia-vaapi-driver
    nvtopPackages.nvidia
    python3
    pavucontrol
    amneziawg-tools
    (pkgs.writeShellScriptBin "vpn-toggle" ''
      if /run/current-system/sw/bin/ip rule | grep -q 'lookup 51820'; then
        sudo /run/current-system/sw/bin/ip rule del table 51820 || true
        sudo /run/current-system/sw/bin/ip rule del table main suppress_prefixlength 0 || true
        echo "VPN Routing Disabled - VPN-ul este acum oprit."
      else
        sudo /run/current-system/sw/bin/ip rule add not fwmark 51820 table 51820 || true
        sudo /run/current-system/sw/bin/ip rule add table main suppress_prefixlength 0 || true
        echo "VPN Routing Enabled - VPN-ul este acum pornit."
      fi
    '')
  ];

  security.sudo.extraRules = [
    {
      users = [ "mihai" ];
      commands = [
        { command = "/run/current-system/sw/bin/ip"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/systemctl start sunshine.service"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/systemctl stop sunshine.service"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/systemctl restart sunshine.service"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  # --- PROGRAMS ---
  programs = {
     thunar = {
        enable = true;
        plugins = with pkgs.xfce; [ thunar-archive-plugin thunar-volman ];
     };
  };
  programs.fuse.userAllowOther = true;
  programs.hyprlock.enable = true;
  programs.gpu-screen-recorder.enable = true;
}
