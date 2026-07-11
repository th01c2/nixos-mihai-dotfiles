{ config, pkgs, inputs, ... }: {

  home.username = "mihai";
  home.homeDirectory = "/home/mihai";
  home.stateVersion = "25.05";

  programs.firefox = {
    enable = true;

    profiles.mihai = {
      isDefault = true;

      # Corrected pkgs.system reference for modern Nixpkgs
      extensions.packages = with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [ 
        ublock-origin 
      ];

      search = {
        force = true;
        # Changed "DuckDuckGo" -> "ddg" and "Google" -> "google"
        default = "ddg";
        order = [ "ddg" "google" ];
      };

      settings = {
        "browser.startup.homepage" = "https://duckduckgo.com";
        "browser.newtabpage.enabled" = false;
        "browser.toolbars.bookmarks.visibility" = "always";
        "toolkit.telemetry.enabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "extensions.pocket.enabled" = false;
        "general.smoothScroll" = true;
        
        "extensions.autoDisableScopes" = 0;
        "extensions.enabledScopes" = 15;
        "extensions.startupScanScopes" = 15;
      };
    };
  };

  home.packages = with pkgs; [
    inter
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    font-awesome
  ];
 
  stylix = {
   enable = true;
    targets = {
    };
    icons = {
      enable = true;
      package = pkgs.gruvbox-plus-icons;
      dark = "Gruvbox-Plus-Dark";
    };
};

  home.file = {
  ".local/share/applications/nix-clean.desktop".text = ''
    [Desktop Entry]
    Name=NixOs Clean
    Exec=bash -c 'sudo nix-collect-garbage -d && nix store gc; read'
    Terminal=true
    Type=Application
    Icon=utilities-terminal
    Categories=System;
  '';

    # Hyprland Config 
    ".config/hypr/hyprland.conf".source = ../config/hypr/hyprland.conf;

    # Hyprlock Config
    ".config/hypr/hyprlock.conf".source = ../config/hypr/hyprlock.conf;

    # Hypridle Config
    ".config/hypr/hypridle.conf".source = ../config/hypr/hypridle.conf;

    # Hyprpaper Config
    ".config/hypr/hyprpaper.conf".source = ../config/hypr/hyprpaper.conf;

     # Waybar Config
    ".config/waybar/config".source = ../config/waybar/config;
    ".config/waybar/style.css".source = ../config/waybar/style.css;

    # Foot Terminal Config
    ".config/foot/foot.ini".source = ../config/foot/foot.ini;

     # Fuzzel Config file
    ".config/fuzzel/fuzzel.ini".source = ../config/fuzzel/fuzzel.ini;
};

  programs.home-manager.enable = true;
}
