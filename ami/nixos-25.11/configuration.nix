{ pkgs, config, lib, ... }: {
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  environment.systemPackages = with pkgs; [
    jq
    git
    mc
    gettext
    openssl
    awscli2
  ];

  virtualisation.docker.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  users = {
    users.default = {
      password = "default";
      openssh = {
        authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDUhoQkaFz23hjJYaSDT6Rk+CoQrdNamfO/3at7UsYFUVj3U6Em/5aMEqgZhvJ14FbQvVX78CJbTJb30MYAmsMhvLkvKGpBdhxsd/lwXPrh7hCDdIgqh/X2/E3eDZ05ou1FlGmMAF+gUCzM3qXWvPGzlSfoEImCu/YeIhiyhMIvkoTPMl5eD6VTGYOvLM4meFzxHOEOm2uFKOs5hz/5UpefMZnMHqFzYq9sE0tgiFF87eHWAbsXrX9zprJO6Tn9SYVKGCyrgGe0bvTp1uZuO0zvGjILPhVdo+xXEcrhWX8QFFU26vzByb8DdHVuI+4Dv2j5PnxKTyLGuGe+yaSoTdYycLn+z+5Z34lZXJeoHDbeOVOU4BheiqisMCy82tCNQ0H28OiGcYOzYE7lIz5i6lSgCK3VDw+pzPFqaKCqiIWXKHTkzozzOM87HpkfG1Qnef1JDUhC/2izxys7SOrOwWhQp8NxB52CjFR0rdQJGC/jAPQneeSQKvr7u0e11UhLz7M= stefano@ubuntu"
        ];
      };
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };

  system.stateVersion = "25.11";
}