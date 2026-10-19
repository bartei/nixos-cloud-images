# NixOS cloud images

[![release](https://img.shields.io/github/v/release/bartei/nixos-cloud-images?sort=semver)](https://github.com/bartei/nixos-cloud-images/releases/latest)
[![release workflow](https://github.com/bartei/nixos-cloud-images/actions/workflows/release.yml/badge.svg)](https://github.com/bartei/nixos-cloud-images/actions/workflows/release.yml)
[![license: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](LICENSE)

Ready-to-run, reproducible [NixOS](https://nixos.org) images for common cloud and
virtualisation targets, built from plain Nix flakes and published as GitHub Release
assets. Every release rebuilds every image; the `nixpkgs` pins are refreshed
automatically once a month so the latest release always carries current packages
and security fixes.

| Image | Target | Format | Asset name |
|-------|--------|--------|------------|
| **vm**  | Proxmox VE, QEMU/KVM, libvirt, OpenStack, anything that boots qcow2 with cloud-init | compressed qcow2 | `nixos-<version>-vm.qcow2` |
| **ami** | Amazon EC2 (import as an AMI) | dynamic VHD, zstd-compressed | `nixos-<version>-ami.vhd.zst` |
| **lxc** | Proxmox VE containers | tar.xz template | `nixos-<version>-lxc.tar.xz` |

Each asset is accompanied by a `<asset>.sha256` checksum file. All images are
`x86_64-linux`.

## Supported NixOS versions

| Version | vm | ami | lxc |
|---------|:--:|:---:|:---:|
| 26.05 | ✓ | ✓ | ✓ |
| 25.11 | ✓ | ✓ |   |
| 25.05 | ✓ | ✓ |   |

Images for a version are built as long as its directory exists under `vm/`, `ami/`
or `lxc/`. Versions whose upstream `nixos-*` branch has stopped moving still build,
but no longer receive updates.

## Download

Grab assets from the [latest release](https://github.com/bartei/nixos-cloud-images/releases/latest).
Stable URLs for scripts:

```sh
# Latest release of a given asset
curl -LO https://github.com/bartei/nixos-cloud-images/releases/latest/download/nixos-26.05-vm.qcow2
curl -LO https://github.com/bartei/nixos-cloud-images/releases/latest/download/nixos-26.05-vm.qcow2.sha256
sha256sum -c nixos-26.05-vm.qcow2.sha256
```

Replace `latest` with a tag such as `v1.6.1` to pin a specific release.

## Using the images

### vm — Proxmox VE / QEMU

The qcow2 image boots with GRUB on a legacy partition table, grows its root
filesystem to the disk on first boot, and runs [cloud-init](https://cloudinit.readthedocs.io/)
with network configuration enabled. The QEMU guest agent is installed.

Proxmox example (adjust the VM id, storage and bridge):

```sh
qm create 9000 --name nixos-26.05 --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci --serial0 socket --vga serial0 --agent enabled=1
qm importdisk 9000 nixos-26.05-vm.qcow2 local-lvm
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0 --boot order=scsi0
qm set 9000 --ide2 local-lvm:cloudinit --ciuser default --sshkeys ~/.ssh/id_ed25519.pub --ipconfig0 ip=dhcp
qm template 9000
```

Plain QEMU, with a NoCloud seed for cloud-init:

```sh
qemu-img create -f qcow2 -b nixos-26.05-vm.qcow2 -F qcow2 disk.qcow2 20G
qemu-system-x86_64 -enable-kvm -m 2048 -nographic \
  -drive file=disk.qcow2,if=virtio \
  -drive file=seed.iso,if=virtio,format=raw \
  -nic user,model=virtio,hostfwd=tcp::2222-:22
```

### ami — Amazon EC2

The `.vhd.zst` is a dynamic VHD produced by the nixpkgs Amazon image module. To turn
it into an AMI, decompress it, upload it to S3, import it as a snapshot and
register an image from the snapshot:

```sh
zstd -d nixos-26.05-ami.vhd.zst
aws s3 cp nixos-26.05-ami.vhd s3://<bucket>/nixos-26.05-ami.vhd
aws ec2 import-snapshot --description "NixOS 26.05" \
  --disk-container "Format=VHD,UserBucket={S3Bucket=<bucket>,S3Key=nixos-26.05-ami.vhd}"
# wait for the import task, note the SnapshotId, then:
aws ec2 register-image --name "nixos-26.05" --architecture x86_64 \
  --virtualization-type hvm --ena-support --root-device-name /dev/xvda \
  --block-device-mappings "DeviceName=/dev/xvda,Ebs={SnapshotId=<snap-id>,VolumeType=gp3}"
```

The import role and bucket permissions AWS requires are described in the
[VM Import/Export documentation](https://docs.aws.amazon.com/vm-import/latest/userguide/).

On first boot the image reads the instance metadata (IMDSv2) and installs the key
pair selected at launch as an authorized key for `root`, so you log in with
`ssh -i <keypair>.pem root@<host>`. There is no cloud-init: user data is handled by
the nixpkgs `amazon-init` service, which runs it as a shell script if it starts
with `#!`, or applies it with `nixos-rebuild switch` if it is a NixOS configuration
expression. Cloud-config YAML is ignored. The image ships `awscli2`, `git`, `jq`,
`openssl` and `gettext`.

### lxc — Proxmox VE container template

Copy the tarball to a Proxmox template store and create a container from it. The
image is built with the nixpkgs `proxmox-lxc` module. Networking comes from the
container's Proxmox configuration, and the keys given with `--ssh-public-keys` are
written by Proxmox into root's `authorized_keys`, so you log in as `root` with that
key or open a console with `pct enter`.

```sh
scp nixos-26.05-lxc.tar.xz root@pve:/var/lib/vz/template/cache/
pct create 200 local:vztmpl/nixos-26.05-lxc.tar.xz --hostname nixos --memory 1024 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --ssh-public-keys ~/.ssh/id_ed25519.pub \
  --unprivileged 1 --features nesting=1 --ostype unmanaged
```

## Access

No image contains a baked-in SSH key, and SSH password authentication is disabled
in all of them. Root login over SSH is key-only (`PermitRootLogin prohibit-password`).

| Image | Accounts | How a key gets in |
|-------|----------|-------------------|
| **vm**  | `default` (in `wheel`, passwordless `sudo`, console password `default`) and `root` | cloud-init, for example `--ciuser default --sshkeys …` in Proxmox or a NoCloud seed |
| **ami** | `root` only | the EC2 key pair chosen at launch, installed from instance metadata on first boot |
| **lxc** | `root` only | Proxmox writes `--ssh-public-keys` into root's `authorized_keys` at creation |

On the vm image, change or remove the `default` user's password after first login
if the console is reachable by others. Add users with cloud-init, or rebuild the
image with your own `configuration.nix`.

## Building locally

Requirements: Nix with flakes enabled and, for the vm and ami images, access to
`/dev/kvm` (the disk images are assembled inside a QEMU VM).

```sh
nix build ./vm/nixos-26.05#image    # → result/nixos.qcow2
nix build ./ami/nixos-26.05#image   # → result/*.vhd
nix build ./lxc/nixos-26.05#image   # → result/tarball/*.tar.xz
```

Each image is an independent flake in `<kind>/nixos-<version>/` with its own
`flake.lock`, so one version can move without touching the others.

## How releases happen

Commits on `main` follow [Conventional Commits](https://www.conventionalcommits.org/).
On every push, [python-semantic-release](https://python-semantic-release.readthedocs.io/)
derives the next version from the commit messages (`fix` → patch, `feat` → minor,
breaking change → major), updates `CHANGELOG.md`, tags, and creates the GitHub
Release. A build job per image then attaches the assets. On the 1st of every month
the pipeline first runs `nix flake update` in every image and commits the result as
a `fix(deps)` change, so a fresh patch release goes out with current `nixpkgs`.

The pipeline lives in [`.github/workflows/release.yml`](.github/workflows/release.yml);
its design notes are in [`.github/github_design.md`](.github/github_design.md).

## Contributing

Bug reports, new targets and new NixOS versions are welcome. Please read
[CONTRIBUTING.md](CONTRIBUTING.md) first; the commit message convention matters
because it drives releases.

## License

This project is licensed under the GNU General Public License, version 3 or later
(`GPL-3.0-or-later`). See [LICENSE](LICENSE). The images contain software under
many licences; NixOS and nixpkgs are MIT-licensed, and each package carries its
own.
