# TODO: configure zmk-nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    zmk-nix = {
      url = "github:lilyinstarlight/zmk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      zmk-nix,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs (nixpkgs.lib.attrNames zmk-nix.packages);
    in
    {
      packages = forAllSystems (system: rec {
        default = firmware;

        firmware = zmk-nix.legacyPackages.${system}.buildSplitKeyboard {
          name = "firmware";

          src = nixpkgs.lib.sourceFilesBySuffices self [
            ".board"
            ".cmake"
            ".conf"
            ".defconfig"
            ".dts"
            ".dtsi"
            ".json"
            ".keymap"
            ".overlay"
            ".shield"
            ".yml"
            "_defconfig"
          ];

          board = "adv360_%PART%";
          enableZmkStudio = true;

          zephyrDepsHash = "sha256-0tNjgMiepoGr/eGPvxSyRaKTekoZ8KqAAoLG3HAPKq8=";

          meta = {
            description = "ZMK firmware";
            license = nixpkgs.lib.licenses.mit;
            platforms = nixpkgs.lib.platforms.all;
          };
        };

        flash = zmk-nix.packages.${system}.flash.override { inherit firmware; };
        update = zmk-nix.packages.${system}.update;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          baseShell = zmk-nix.devShells.${system}.default;
          zmk-launcher = pkgs.writeShellScriptBin "zmk" ''
            ${pkgs.zmk-studio}/bin/zmk-studio < /dev/null > /dev/null 2>&1 & disown
          '';

          flash-left = pkgs.writeShellScriptBin "flash" ''
            SIDE="$1"
            if [[ $SIDE != "left" && $SIDE != "right" ]]; then 
                echo "Specify side: left or right"
                exit 1
            fi

            if [ ! -d "result" ]; then
              echo "Error: 'result' directory not found. Run 'nix build' first."
              exit 1
            fi

            if udisksctl mount -b /dev/sda; then
               cp -L "result/zmk_$SIDE.uf2" /run/media/vladyslav/ADV360PRO/
               sync
               # udisksctl unmount -b /dev/sda1
               echo "Flash complete! Keyboard will reboot."
            else
               echo "Error: Could not mount keyboard side. Is the keyboard in bootloader mode? Also check device mount point with lsblk"
            fi
          '';
        in
        {
          default = pkgs.mkShell {
            name = "zmk";
            inputsFrom = [ baseShell ];
            nativeBuildInputs = with pkgs; [
              flash-left
              zmk-studio
              zmk-launcher
            ];
            shellHook = ''
              export GDK_BACKEND=wayland
            '';
          };
        }
      );
    };
}
