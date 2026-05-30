{
  description = "Custom NixOS ISO for Mihai";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
   stylix = {
      url = "github:danth/stylix/";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    prismlauncher-cracked.url = "github:Diegiwg/PrismLauncher-Cracked";
  };

  outputs = { self, nixpkgs, home-manager, plasma-manager, firefox-addons, prismlauncher-cracked, ... }@inputs: {
    nixosConfigurations.nixos-mihai = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        {
          nixpkgs.overlays = [ inputs.firefox-addons.overlays.default ];
          nixpkgs.hostPlatform = "x86_64-linux";
        }
        ./nixos/configuration.nix
	inputs.stylix.nixosModules.stylix
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.mihai = {
            imports = [
              ./home-manager/home.nix
              plasma-manager.homeModules.plasma-manager
            ];
          };
        }
      ];
    };
  };
}
