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

  users = {
    users.root.linger = true;
    users.default = {
      password = "default";
      openssh = {
        authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMwNtFGWDlc1VFhVmVvdV7bTLPjC5CoGQOj0zSsJJpR2 stefanob@manjaro-lab"
        ];
      };
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };

  system.stateVersion = "26.05";
}
