{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
  };
  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    rec {
      # qcow2 (qemu/proxmox) cloud image.
      image = nixosConfigurations.this.config.system.build.qemuImage;

      nixosConfigurations.this = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
      };
    };
}
