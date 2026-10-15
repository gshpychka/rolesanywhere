{
  description = "AWS credentials for a NixOS machine's local users through IAM Roles Anywhere, from a CA in its TPM2";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      # shared by `nix fmt` and the treefmt check
      formatTools =
        pkgs: with pkgs; [
          treefmt
          nixfmt
          ruff
          taplo
          opentofu
        ];
    in
    {
      nixosModules.default = ./module.nix;

      packages = forAllSystems (pkgs: {
        default = pkgs.callPackage ./package { };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.opentofu
            pkgs.awscli2
          ]
          ++ formatTools pkgs;
        };
      });

      formatter = forAllSystems (
        pkgs:
        pkgs.writeShellApplication {
          name = "treefmt";
          runtimeInputs = formatTools pkgs;
          text = ''exec treefmt "$@"'';
        }
      );

      checks = forAllSystems (
        pkgs:
        {
          # runs the unit tests
          package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
          # copy out of the read-only store so treefmt can rewrite in place,
          # then fail if anything changed
          treefmt = pkgs.runCommand "check-treefmt" { nativeBuildInputs = formatTools pkgs; } ''
            cp -r --no-preserve=mode,ownership ${self} src
            cd src
            HOME=$TMPDIR treefmt --no-cache --fail-on-change --tree-root .
            touch $out
          '';
          ruff = pkgs.runCommand "check-ruff" { nativeBuildInputs = [ pkgs.ruff ]; } ''
            cd ${self}
            ruff check --no-cache .
            touch $out
          '';
        }
        # x86_64 is the only platform the VM test has run on
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
          vm = import ./tests/vm.nix {
            inherit pkgs;
            module = self.nixosModules.default;
          };
        }
      );
    };
}
