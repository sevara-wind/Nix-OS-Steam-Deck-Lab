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
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, deck, jovian, nix-crab, home-manager, nixos-generators, ... }@inputs:
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
        ./configuration.nix
      ] ++ extraModules;
    };

  in {
    nixosModules = myModules;

    homeModules.steamidra = deck.homeModules.steamidra;

    nixosConfigurations = {

      installer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inputs = inputs // { self = deck; };
          installerSource = ./.;
        };
        modules = [
          nixos-generators.nixosModules.iso
          myModules.myDeck
          myModules.installer
        ];
      };

      deck = mkDeck [];

      deck-disk = mkDeck [
        nixos-generators.nixosModules.raw-efi
        {
          virtualisation.diskSize = "16G";
        }
        ({
          lib,
          ...
        }: {
          boot.loader.limine.enable = lib.mkForce false;
          boot.loader.systemd-boot.enable = lib.mkForce false;
          boot.loader.grub = {
            enable = true;
            device = "nodev";
            efiSupport = true;
            efiInstallAsRemovable = true;
            configurationLimit = 10;
          };
          boot.loader.efi.canTouchEfiVariables = false;
        })
      ];
    };

    packages.x86_64-linux = {
      installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;
      deck-disk = self.nixosConfigurations.deck-disk.config.system.build.raw;
    };
  };
}
