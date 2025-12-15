{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixos-generators,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    mkImage = config:
      nixos-generators.nixosGenerate {
        inherit system;
        format = "qcow";
        modules = [config];
      };

    # Deploy script that copies the built image
    mkDeployScript = name:
      pkgs.writeShellScript "deploy-${name}" ''
        set -e
        echo "Building ${name} image..."
        ${pkgs.nix}/bin/nix build .#${name}

        DEST="/var/lib/libvirt/images/ISOs/nixos_${name}.qcow2"

        echo "Copying to $DEST..."
        sudo cp -f result/nixos.qcow2 "$DEST"
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
          ${pkgs.nix}/bin/nix build .#server .#desktop .#osint

          echo "Checking hashes..."
          for NAME in server desktop osint; do
            IDX=1
            case $NAME in
                server) IDX=1 ;;
                desktop) IDX=2 ;;
                osint) IDX=3 ;;
            esac
            SRC="result-$i/nixos.qcow2"
            DEST="/var/lib/libvirt/images/ISOs/nixos_$NAME.qcow2"

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
