{ config, lib, pkgs, installerSource, ... }:

{
  # ── Live ISO boot ──────────────────────────────────────────────
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Networking ─────────────────────────────────────────────────
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  # ── Root access for live system ────────────────────────────────
  users.users.root.initialPassword = "";

  services.displayManager.autoLogin = {
    enable = true;
    user   = "root";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin        = "yes";
    };
  };

  # ── Embed our flake source into the ISO ────────────────────────
  environment.etc.nixos-installer = {
    source    = installerSource;
    recursive = true;
  };

  # ── Packages + installer script ────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    vim
    nano
    parted
    btrfs-progs
    dosfstools
    nixos-install-tools
    curl
    wget
    htop

    (writeShellScriptBin "setup-deck" ''
      #!/usr/bin/env bash
      set -euo pipefail

      echo "╔══════════════════════════════════════╗"
      echo "║     Steam Deck NixOS Installer       ║"
      echo "╚══════════════════════════════════════╝"
      echo

      # ── Gather parameters ──
      read -rp "Username [deck]: " MY_USER
      MY_USER=''${MY_USER:-deck}

      read -rsp "Password: " MY_PASS; echo
      while [ -z "$MY_PASS" ]; do
        read -rsp "Password (cannot be empty): " MY_PASS; echo
      done

      read -rp "Panel [lcd/oled] (default: lcd): " MY_PANEL
      MY_PANEL=''${MY_PANEL:-lcd}

      read -rp "Timezone (default: Europe/Moscow): " MY_TZ
      MY_TZ=''${MY_TZ:-Europe/Moscow}

      # ── Detect disks ──
      echo
      echo "Available block devices:"
      lsblk -dno NAME,SIZE,MODEL | grep -Ev "loop|sr|ram"
      echo
      read -rp "Target disk (default: nvme0n1): " MY_DISK
      MY_DISK=''${MY_DISK:-nvme0n1}
      DISK="/dev/$MY_DISK"

      # ── Confirm ──
      echo
      echo "┌─────────────────────────────┐"
      echo "│ User:     $MY_USER"
      echo "│ Panel:    $MY_PANEL"
      echo "│ Timezone: $MY_TZ"
      echo "│ Disk:     $DISK"
      echo "└─────────────────────────────┘"
      read -rp "Proceed? [y/N]: " CONFIRM
      [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

      # ── Partition ──
      echo
      echo ">>> Partitioning $DISK ..."
      parted -s "$DISK" -- mklabel gpt
      parted -s "$DISK" -- mkpart ESP fat32 1MiB 1025MiB
      parted -s "$DISK" -- set 1 esp on
      parted -s "$DISK" -- mkpart root 1025MiB 100%

      echo ">>> Formatting ..."
      mkfs.vfat -F32 -n EFI "''${DISK}p1"
      mkfs.btrfs -L nixos -f "''${DISK}p2"

      # ── BTRFS subvolumes ──
      echo ">>> Creating BTRFS subvolumes ..."
      mount "''${DISK}p2" /mnt
      btrfs subvolume create /mnt/@
      btrfs subvolume create /mnt/@home
      btrfs subvolume create /mnt/@nix
      umount /mnt

      echo ">>> Mounting ..."
      mount -o "subvol=@,compress=zstd,noatime" "''${DISK}p2" /mnt
      mkdir -p /mnt/{home,nix,boot}
      mount -o "subvol=@home,compress=zstd,noatime" "''${DISK}p2" /mnt/home
      mount -o "subvol=@nix,compress=zstd,noatime,ssd" "''${DISK}p2" /mnt/nix
      mount "''${DISK}p1" /mnt/boot

      # ── Deploy flake config ──
      echo ">>> Deploying configuration ..."
      rm -rf /mnt/etc/nixos
      mkdir -p /mnt/etc/nixos
      cp -rL /etc/nixos-installer/* /mnt/etc/nixos/
      git -C /mnt/etc/nixos init -b main 2>/dev/null || true
      git -C /mnt/etc/nixos add -A 2>/dev/null || true
      git -C /mnt/etc/nixos commit -m "installer" 2>/dev/null || true

      # ── Generate hardware config for target ──
      echo ">>> Generating hardware-configuration.nix ..."
      nixos-generate-config --root /mnt

      # ── Install ──
      echo ">>> Installing NixOS (flake#deck) ..."
      HASH=$(nix-shell -p mkpasswd --run "mkpasswd -m SHA-512 ''$MY_PASS'")
      export MYDECK_USERNAME="$MY_USER"
      export MYDECK_PASSWORD_HASH="$HASH"
      export MYDECK_PANEL="$MY_PANEL"
      export MYDECK_TIMEZONE="$MY_TZ"

      nixos-install --flake /mnt/etc/nixos#deck --impure --no-root-passwd

      echo
      echo "══════════════════════════════════"
      echo "  Installation complete!"
      echo "  Remove USB and reboot."
      echo "══════════════════════════════════"
    '')
  ];
}
