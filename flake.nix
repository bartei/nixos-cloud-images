{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixos-generators.url = "github:nix-community/nixos-generators";
  };
  outputs = { self, nixpkgs, nixos-generators, ... }:
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

        ami = nixos-generators.nixosGenerate {
          inherit system;
          format = "amazon";
          modules = [
          {
            virtualisation.diskSize = 40 * 1024;
          }
          ./dockerConfiguration.nix
          ];
        };

        amazonImage = dockerImage.config.system.build;

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
