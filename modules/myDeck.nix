{ lib, ... }:

{
  options.myDeck = {

    username = lib.mkOption {
      type = lib.types.str;
      description = "Primary user account name.";
      default = let v = builtins.getEnv "MYDECK_USERNAME"; in if v != "" then v else "deck";
    };

    passwordHash = lib.mkOption {
      type = lib.types.str;
      description = "SHA-512 hashed password for the primary user (mkpasswd -m SHA-512).";
      default = builtins.getEnv "MYDECK_PASSWORD_HASH";
    };

    panel = lib.mkOption {
      type = lib.types.enum [ "lcd" "oled" ];
      description = "Steam Deck display panel type.";
      default = let v = builtins.getEnv "MYDECK_PANEL"; in if v != "" then v else "lcd";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      description = "System timezone.";
      default = let v = builtins.getEnv "MYDECK_TIMEZONE"; in if v != "" then v else "Europe/Moscow";
    };

  };
}
