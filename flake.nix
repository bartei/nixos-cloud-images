{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  };
  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    rec {
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
