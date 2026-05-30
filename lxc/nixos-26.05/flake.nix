{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  };

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      name = "nixos";
      version = "26.05";
    in rec {
      image = nixosConfigurations.this.config.system.build.tarball.override {
        fileName = "${name}-${system}-${version}";
      };

      nixosConfigurations = {
        this = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./configuration.nix
            "${nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
          ];
        };
      };

    };
}
