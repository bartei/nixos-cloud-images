{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
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

        # Amazon/EC2 image via the native nixpkgs image framework (nixos-generators
        # was deprecated in 25.05). Tracks this folder's nixpkgs; outputs a .vhd.
        ami = (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./dockerConfiguration.nix
            { image.modules.amazon.virtualisation.diskSize = 8 * 1024; }
          ];
        }).config.system.build.images.amazon;

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