{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    flake-utils,
    nix-filter,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        filter = nix-filter.lib;

        craneLib = crane.mkLib pkgs;
        commonArgs = {
          src = filter {
            root = ./.;
            include = [
              ./Cargo.toml
              ./Cargo.lock
              ./src
              ./build.rs
              ./rift.default.toml
              ./assets/Info.plist
            ];
          };

          strictDeps = true;
          buildInputs = [
            pkgs.libiconv
          ];
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
      in {
        packages = {
          default = craneLib.buildPackage (
            commonArgs
            // {
              inherit cargoArtifacts;
            }
          );
        };

        devShells.default = craneLib.devShell {
          packages = with pkgs; [rust-analyzer clippy rustfmt];
        };
      }
    )
    // {
      overlays.default = _: super: {
        rift = self.outputs.packages.${super.system}.default;
      };

      darwinModules.rift = {
        pkgs,
        config,
        ...
      }: let
        inherit (nixpkgs) lib;
        cfg = config.services.rift;
      in {
        options.services.rift = {
          enable = lib.mkEnableOption "Rift window manager";
          package = lib.mkPackageOption pkgs "rift" {};
        };

        config = lib.mkIf cfg.enable {
          nixpkgs.overlays = [self.overlays.default];
          environment.systemPackages = [pkgs.rift];
        };
      };
    };
}
