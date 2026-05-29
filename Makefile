CURRENT_DATE := $(shell date +%Y-%m-%d)
IMAGE_NAME := nixos
SERVER_URL := cloud-images.opt.provvedo.com

build-push:
	nix build .\#nixosConfigurations.this.config.system.build.qemuImage -L
	ssh default@$(SERVER_URL) mkdir -p /data/cloud-images
	ssh default@$(SERVER_URL) rm -rf /data/cloud-images/$(IMAGE_NAME)-$(CURRENT_DATE).*
	scp ./result/nixos.qcow2 default@$(SERVER_URL)://data/cloud-images/$(IMAGE_NAME)-$(CURRENT_DATE).qcow2
	ssh default@$(SERVER_URL) ln -sf /data/cloud-images/$(IMAGE_NAME)-$(CURRENT_DATE).qcow2 /data/cloud-images/$(IMAGE_NAME)-latest.qcow2
