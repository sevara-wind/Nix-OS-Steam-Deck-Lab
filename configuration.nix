{ config, pkgs, lib, inputs, ... }:

let
  username = config.myDeck.username;
  pwHash   = config.myDeck.passwordHash;
  isOled   = config.myDeck.panel == "oled";
in
{
  system.stateVersion = "24.11";
  networking.hostName = if isOled then "steamdeck-oled" else "steamdeck";
  networking.networkmanager.enable = true;
  time.timeZone = config.myDeck.timezone;

  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "ru_RU.UTF-8/UTF-8"
  ];

  boot.loader = {
    systemd-boot.enable = false;
    grub.enable = false;

    limine = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;

      style.wallpapers = [ ./wallpaper.png ];

      extraConfig = ''
        interface_rotation: ${if isOled then "270" else "90"}
        graphics: yes
        timeout: 5

        wallpaper_style: stretch
        background_color: #00000000
        text_color: #ffffffff
        text_highlight_color: #ff00ffff
      '';
    };

    efi.canTouchEfiVariables = true;
  };

  boot.kernelParams =
    if isOled then
      [ "video=DSI-1:panel_orientation=upside_down" "fbcon=rotate:3" ]
    else
      [ "video=DSI-1:panel_orientation=right_side_up" "fbcon=rotate:1" ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  jovian = {
    devices.steamdeck.enable = true;
    steamos.useSteamOSConfig = true;
    hardware.has.amd.gpu = true;
    decky-loader.enable = true;
    steam = {
      enable = true;
      autoStart = true;
      user = username;
      desktopSession = "gnome";
    };
  };

  programs.nix-crab = {
    slssteam.enable = true;
    slssteam-moon.enable = true;
    cloudredirect.enable = true;
    cloudredirect.moon.enable = true;
  };

  hardware.enableRedistributableFirmware = true;
  security.rtkit.enable = true;

  services.xserver.enable = true;
  services.desktopManager.gnome.enable = true;
  services.flatpak.enable = true;
  xdg.portal.enable = true;
  services.displayManager.gdm.enable = lib.mkForce false;

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  users.users.${username} = {
    isNormalUser = true;
    description  = username;
    extraGroups  = [ "wheel" "networkmanager" "audio" "video" "input" ];
  } // lib.optionalAttrs (pwHash != "") {
    hashedPassword = pwHash;
  };

  users.users.root.hashedPassword = lib.mkIf (pwHash != "") pwHash;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };

  programs.throne = {
    enable = true;
    tunMode.enable = true;
  };

  environment.systemPackages = with pkgs; [
    nano
    git
    htop
    firefox
    curl
    procps
    gawk
    gnugrep
    coreutils
    findutils
    util-linux
    go
    psmisc
    fastfetch
    appimage-run
    steam-run
    bashInteractive
    shared-mime-info
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username} = {
      home.stateVersion = "24.11";
      imports = [
        inputs.self.homeModules.steamidra
      ];
      programs.nix-crab = {
        luatools.enable = true;
        cloudredirect.moon.enable = true;
        steamidra.enable = true;
        accela.enable = true;
      };
    };
  };
}
