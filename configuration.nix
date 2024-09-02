{ config, pkgs, ... }:

{
  imports = [ <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix> ];

  # Set hostname
  networking.hostName = "nixos-cloud";

  # Enable SSH service
  services.openssh.enable = true;

  # Enable KVM guest support
  boot.kernelModules = [ "kvm-intel" ];

  # Set root password (for example, set it to 'nixos')
  users.users.root.initialPassword = "nixos";

  # Add cloud-init for cloud configuration (optional)
  services.cloud-init.enable = true;

  # Basic system settings
  time.timeZone = "UTC";
  networking.useDHCP = true;
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
  ];

  # Ensure systemd services are enabled
  systemd.services.sshd.wantedBy = [ "multi-user.target" ];

  # Make the image smaller by removing unnecessary packages
  boot.cleanTmpDir = true;
  environment.noXlibs = true;

  # Ensure that the image can boot
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/sda" ];
  boot.loader.grub.version = 2;
}