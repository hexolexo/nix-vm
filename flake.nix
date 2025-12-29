{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixos-generators,
    home-manager,
    nur,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    mkImage = config:
      nixos-generators.nixosGenerate {
        inherit system;
        format = "qcow";
        modules = [
          config
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [
              (final: prev: {
                nur = import nur {
                  pkgs = final;
                  nurpkgs = final;
                };
              })
            ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        ];
      };

    # Deploy script that copies the built image
    mkDeployScript = name:
      pkgs.writeShellScript "deploy-${name}" ''
        set -e
        echo "Building ${name} image..."
        rm -f result  # Clear any existing result symlinks
        ${pkgs.nix}/bin/nix build .#${name} --out-link result
        DEST="/var/lib/libvirt/images/ISOs/nixos_${name}.qcow2"
        echo "Copying to $DEST..."
        sudo rsync --inplace result/nixos.qcow2 "$DEST"
        #sudo cp -f result/nixos.qcow2 "$DEST" # Might be faster lets see
        sudo chown root:root "$DEST"
        sudo chmod 644 "$DEST"
        echo "✓ ${name} deployed"
      '';
  in {
    packages.${system} = {
      server = mkImage ./server.nix;
      desktop = mkImage ./desktop.nix;
      osint = mkImage ./osint.nix;

      default = self.packages.${system}.server;
    };

    apps.${system} = {
      deploy-server = {
        type = "app";
        program = toString (mkDeployScript "server");
      };
      deploy-desktop = {
        type = "app";
        program = toString (mkDeployScript "desktop");
      };
      deploy-osint = {
        type = "app";
        program = toString (mkDeployScript "osint");
      };
      deploy-all = {
        type = "app";
        program = toString (pkgs.writeShellScript "deploy-all" ''
          set -e
          echo "Building all images..."
          # HACK: Explicit out-links because parallel builds don't guarantee result-N order
          ${pkgs.nix}/bin/nix build .#server --out-link result-server
          ${pkgs.nix}/bin/nix build .#desktop --out-link result-desktop
          ${pkgs.nix}/bin/nix build .#osint --out-link result-osint

          echo "Checking hashes..."
          for NAME in server desktop osint; do
            SRC="result-$NAME/nixos.qcow2"
            DEST="/var/lib/libvirt/images/ISOs/nixos_$NAME.qcow2"

            if [ ! -f "$SRC" ]; then
              echo "✗ $NAME build failed, skipping"
              continue
            fi

            SRC_HASH=$(${pkgs.b3sum}/bin/b3sum "$SRC" | cut -d' ' -f1)
            if [ -f "$DEST" ]; then
              DEST_HASH=$(${pkgs.b3sum}/bin/b3sum "$DEST" | cut -d' ' -f1)
              if [ "$SRC_HASH" = "$DEST_HASH" ]; then
                echo "⊘ $NAME unchanged, skipping"
                continue
              fi
            fi
            echo "Copying $NAME..."
            sudo cp -f "$SRC" "$DEST"
            sudo chown root:root "$DEST"
            sudo chmod 644 "$DEST"
            echo "✓ $NAME deployed"
          done
        '');
      };
      default = self.apps.${system}.deploy-all;
    };
  };
}
