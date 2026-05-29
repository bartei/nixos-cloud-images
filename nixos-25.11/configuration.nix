{ config, pkgs, modulesPath, lib, ... }: {
  imports = [
    # Make sure to have this in all your configurations
    "${toString modulesPath}/profiles/qemu-guest.nix"
  ];

  system.build.qemuImage = import "${toString modulesPath}/../lib/make-disk-image.nix" {
    inherit pkgs lib config;
    partitionTableType = "legacy";
    format = "qcow2-compressed";
    copyChannel = true;
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };

  boot = {
    growPartition = true;
    kernelParams = [ "console=ttyS0" ];
    loader.grub = {
      splashImage = null;
      extraConfig = ''
        serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
        terminal_input --append serial
        terminal_output --append serial
      '';
      device = "/dev/sda";
    };
    loader.timeout = 0;
    initrd.availableKernelModules = [
      "uas"
      "virtio_blk"
      "virtio_pci"
    ];
  };

  networking = {
    firewall.enable = false;
    hostName = lib.mkForce "";
    useDHCP = false;
  };

  services = {
    cloud-init = {
      enable = true;
      network.enable = true;
    };
    sshd.enable = true;
    qemuGuest.enable = true;
  };

  # Allow root logins
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };

  services.openssh.settings.PasswordAuthentication = false;
  security.sudo.wheelNeedsPassword = false;

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # Basic system settings
  time.timeZone = "UTC";

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    mc
  ];

  users = {
    users.default = {
      password = "default";
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };
}