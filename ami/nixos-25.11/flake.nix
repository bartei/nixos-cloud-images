{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
  };
  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    {
      # Amazon/EC2 image via the native nixpkgs image framework; outputs a .vhd.
      image = (nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          { image.modules.amazon.virtualisation.diskSize = 8 * 1024; }
        ];
      }).config.system.build.images.amazon;
    };
}
