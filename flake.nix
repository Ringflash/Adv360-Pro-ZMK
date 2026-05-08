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
        in
        {
          default = pkgs.mkShell {
            name = "zmk";
            inputsFrom = [ baseShell ];
            nativeBuildInputs = with pkgs; [
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
