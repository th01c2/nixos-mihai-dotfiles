{ config, pkgs, ... }:

{
    programs.bash.shellAliases = {
      rbs = "sudo nixos-rebuild switch --flake ~/dotfiles#nixos-mihai";
      macro = "./cscripts/roblox-macro";
    };
    programs.fish.shellAliases = {
      rbs = "sudo nixos-rebuild switch --flake ~/dotfiles#nixos-mihai";
    };
}
