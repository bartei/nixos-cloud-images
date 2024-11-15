CURRENT_DATE := $(shell date +%Y-%m-%d)
IMAGE_NAME := nixos

build-push:
	nix build .\#nixosConfigurations.this.config.system.build.qemuImage -L
	ssh default@cloud-images.internal.provvedo.com mkdir -p /data/cloud-images
	ssh default@cloud-images.internal.provvedo.com rm -rf /data/cloud-images/$(IMAGE_NAME)-$(CURRENT_DATE).*
	scp ./result/nixos.qcow2 default@cloud-images.internal.provvedo.com://data/cloud-images/$(IMAGE_NAME)-$(CURRENT_DATE).qcow2
	ssh default@cloud-images.internal.provvedo.com ln -sf /data/cloud-images/$(IMAGE_NAME)-$(CURRENT_DATE).qcow2 /data/cloud-images/$(IMAGE_NAME)-latest.qcow2
