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

  # --- WINDOW MANAGER, DESKTOP & LOGIN ---
  services.xserver.enable = true;
  services.xserver.windowManager.bspwm.enable = true;

  # KDE Plasma desktop for olesea
  services.desktopManager.plasma6.enable = true;

  services.xserver.displayManager.startx.enable = true;

  # greetd display manager with tuigreet — auto-routes sessions by username
  services.greetd = let
    desktops = config.services.displayManager.sessionData.desktops;
    session-router = pkgs.writeShellScript "session-router" ''
      case "$USER" in
        olesea)
          exec ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland
          ;;
        *)
          exec ${pkgs.xorg.xinit}/bin/startx ${pkgs.bspwm}/bin/bspwm -- :0 vt"$XDG_VTNR"
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
    extraGroups = [ "wheel" "networkmanager" "video" "dialout" "uinput" "render" ];
    packages = with pkgs; [
      inputs.prismlauncher-cracked.packages.${pkgs.stdenv.hostPlatform.system}.prismlauncher
      picom
      bspwm
      sxhkd
      dmenu
      rofi
      polybarFull
      feh
      xinit
      xclip
      maim
      alacritty
      gruvbox-plus-icons
      discord
      vesktop
      telegram-desktop
      steam
      mpv
      xclicker
      android-tools

      # SSH session launcher
      (pkgs.writeShellScriptBin "start-sunshine" ''
        echo "Killing tuigreet..."
        sudo systemctl stop greetd
        sleep 1
        echo "Starting Mihai's bspwm session..."
        sudo systemd-run --unit=mihai-ssh-session --uid=mihai --property=PAMName=login --property=TTYPath=/dev/tty7 --property=StandardInput=tty startx /run/current-system/sw/share/xsessions/none+bspwm.desktop -- vt7
        echo "Sunshine is now active on the host!"
      '')
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
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
    package = pkgs.sunshine.override { cudaSupport = true; };
  };
  hardware.uinput.enable = true;

  # Sunshine needs DISPLAY and XAUTHORITY to capture the X11 session
  systemd.user.services.sunshine.serviceConfig = {
    Environment = [
      "DISPLAY=:0"
      "XAUTHORITY=/home/mihai/.Xauthority"
    ];
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
      if ${pkgs.iproute2}/bin/ip rule | grep -q 'lookup 51820'; then
        sudo ${pkgs.iproute2}/bin/ip rule del table 51820
        sudo ${pkgs.iproute2}/bin/ip rule del table main suppress_prefixlength 0
        ${pkgs.libnotify}/bin/notify-send "VPN Routing Disabled" "Internet is now using the local network." || true
      else
        sudo ${pkgs.iproute2}/bin/ip rule add not fwmark 51820 table 51820
        sudo ${pkgs.iproute2}/bin/ip rule add table main suppress_prefixlength 0
        ${pkgs.libnotify}/bin/notify-send "VPN Routing Enabled" "Internet is routed through the VPN." || true
      fi
    '')
    x11vnc
  ];

  security.sudo.extraRules = [
    {
      users = [ "mihai" ];
      commands = [
        { command = "${pkgs.iproute2}/bin/ip"; options = [ "NOPASSWD" ]; }
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

  # --- SYSTEMD SERVICES ---
  # The VNC service has been completely removed as requested since tuigreet cannot be captured over VNC.

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
