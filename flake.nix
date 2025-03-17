{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  };
  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    rec {

        dockerImage = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./dockerConfiguration.nix
            "${nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
          ];
        };

        tarballImage = dockerImage.config.system.build.tarball.override {
          fileName = "docker-${system}";
        };

        nixosConfigurations = {
        this = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./configuration.nix
          ];
        };
      };
    };
}
