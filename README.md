# nix-vm

Builds NixOS qcow2 images for libvirt VMs using nixos-generators.

Creates pre-configured NixOS desktop images ready to boot in libvirt.

## Requirements

- Nix with flakes enabled
- Root Permission (to write in `/var/lib/libvirt/images/ISOs`)
- libvirt (images deploy to `/var/lib/libvirt/images/ISOs/`)

## Usage

### Build and deploy all images
```bash
nix run  # Builds all, only copies changed images (hash check)
```

### Build specific image
```bash
nix run .#deploy-server
nix run .#deploy-desktop
nix run .#deploy-osint
```

### Just build (no deploy)
```bash
nix build .#server
# Result in ./result/nixos.qcow2
``` 

Used by [unified-tofu](https://github.com/hexolexo/unified-tofu) for VM provisioning.
