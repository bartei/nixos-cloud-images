switch:
	nix-shell --run "NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --target-host root@n8n.internal.provvedo.com --flake .#this -L --impure"

#build:
#	nix-shell --run "nix build .#image -L"
#	scp ./result/tarball/*.tar.xz root@10.1.2.10:/mnt/pve/shared/template/cache/

build:
	nix-shell --run "nix build .#image"
	ssh default@cloud-images.internal.provvedo.com mkdir -p /data/lxc-templates
	$(eval LXC_NAME := $(shell ls ./result/tarball))
	@echo "Image name is: $(LXC_NAME)"
	ssh default@cloud-images.internal.provvedo.com rm -rf /data/lxc-templates/$(LXC_NAME)
	scp ./result/tarball/$(LXC_NAME) default@cloud-images.internal.provvedo.com://data/lxc-templates/$(LXC_NAME)
