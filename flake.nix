{
  description = "Prebuilt Herdr release binaries (herdr-app, herdr-core) as a Nix flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      pins = lib.importJSON ./nix/pins.json;

      overlay = final: _prev: {
        herdr-core = final.callPackage ./nix/herdr-core.nix { pin = pins.herdr-core; };
        herdr-app = final.callPackage ./nix/herdr-app.nix { pin = pins.herdr-app; };
        # nixpkgs' name for the app: the alias replaces its source build too.
        herdr-desktop = final.herdr-app;
      };

      # nixpkgs-unstable has dropped x86_64-darwin; flakeExposed follows it.
      # The overlay still covers that pin for a 26.05 nixpkgs.
      systems = lib.intersectLists lib.systems.flakeExposed (
        lib.unique (lib.concatMap (pin: builtins.attrNames pin.sources) (builtins.attrValues pins))
      );
      forAllSystems =
        f:
        lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
          }
        );
    in
    {
      overlays.default = overlay;

      packages = forAllSystems (
        { pkgs, system }:
        let
          # Each package only on the systems that upstream builds it for.
          ours = lib.filterAttrs (name: _: pins.${name}.sources ? ${system}) {
            inherit (pkgs.extend overlay) herdr-core herdr-app;
          };
        in
        ours // { default = ours.herdr-app or ours.herdr-core; }
      );

      apps = forAllSystems (
        { system, ... }:
        {
          default = {
            type = "app";
            program = lib.getExe self.packages.${system}.default;
            meta.description = self.packages.${system}.default.meta.description;
          };
        }
      );

      checks = forAllSystems ({ system, ... }: removeAttrs self.packages.${system} [ "default" ]);

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt);
    };
}
