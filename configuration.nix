{ config, pkgs, modulesPath, lib, ... }: {
  imports = [
    # Make sure to have this in all your configurations
    "${toString modulesPath}/virtualisation/incus-virtual-machine.nix"
  ];

  services.qemuGuest.enable = true;

  virtualisation.incus.agent.enable = lib.mkForce false;

  services.cloud-init = {
    enable = true;
    network.enable = true;
  };
  
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;

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

  networking.firewall.enable = false;
  networking.useDHCP = lib.mkForce false;
  security.sudo.wheelNeedsPassword = false;

  users = {
    users.default = {
      password = "default";
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };
}