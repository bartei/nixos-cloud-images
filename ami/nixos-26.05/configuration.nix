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

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  system.stateVersion = "26.05";
}