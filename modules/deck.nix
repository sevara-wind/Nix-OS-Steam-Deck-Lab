{ config, lib, inputs, ... }:

let
  username     = config.myDeck.username;
  isCustomUser = username != "sevara";
  pwHash       = config.myDeck.passwordHash;
in
{
  config = {

    # ── System user ──────────────────────────────────────────────
    users.users = lib.mkMerge [
      (lib.mkIf isCustomUser {
        sevara = lib.mkForce {};
      })
      {
        "${username}" = {
          isNormalUser = true;
          description  = username;
          extraGroups  = [ "wheel" "networkmanager" "audio" "video" "input" ];
        } // lib.optionalAttrs (pwHash != "") {
          hashedPassword = pwHash;
        };
        root.hashedPassword = lib.mkForce (
          if pwHash != "" then pwHash else "!"
        );
      }
    ];

    # ── Home Manager user ────────────────────────────────────────
    home-manager.users = lib.mkMerge [
      (lib.mkIf isCustomUser {
        sevara = lib.mkForce {};
      })
      {
        "${username}" = {
          home.stateVersion = "24.11";
          imports = [
            inputs.self.homeModules.noSteamidra
          ];
          programs.nix-crab = {
            luatools.enable       = true;
            cloudredirect.moon.enable = true;
            accela.enable         = true;
          };
        };
      }
    ];

    # ── Jovian steam user ────────────────────────────────────────
    jovian.steam.user = lib.mkForce username;

    # ── Hostname by panel ────────────────────────────────────────
    networking.hostName = lib.mkForce (
      if config.myDeck.panel == "oled" then "steamdeck-oled" else "steamdeck"
    );

    # ── Timezone ─────────────────────────────────────────────────
    time.timeZone = lib.mkForce config.myDeck.timezone;

  };
}
