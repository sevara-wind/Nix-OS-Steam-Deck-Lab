{
  description = "Steam Deck NixOS - Installer ISO & Disk Image Builder";

  inputs = {
    deck.url = "github:sevara-wind/Nix-OS-Steam-Deck";
    deck.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    jovian.url = "github:Jovian-Experiments/Jovian-NixOS";
    nix-crab.url = "github:ItszFinn/nix-crab";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, deck, jovian, nix-crab, home-manager, disko, ... }@inputs:
  let
    myModules = import ./modules;

    mkDeck = extraModules: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inputs = inputs // { self = deck; };
        installerSource = ./.;
      };
      modules = [
        jovian.nixosModules.default
        nix-crab.nixosModules.default
        home-manager.nixosModules.home-manager
        myModules.myDeck
        myModules.deck
        "${deck}/configuration.nix"
      ] ++ extraModules;
    };

  in {
    nixosModules = myModules;

    nixosConfigurations = {

      installer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inputs = inputs // { self = deck; };
          installerSource = ./.;
        };
        modules = [
          myModules.myDeck
          myModules.installer
        ];
      };

      deck = mkDeck [];

      deck-disk = mkDeck [
        disko.nixosModules.disko
        myModules.disk
      ];
    };

    packages.x86_64-linux = {
      installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;
    };
  };
}
