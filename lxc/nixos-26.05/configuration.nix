{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    mc
    vim
    nano
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  networking.firewall.enable = false;

  system.stateVersion = "26.05";
}
