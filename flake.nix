{ 
  description = "A flake for developing & using Clash Shockwaves";
  inputs = {
    clash-compiler.url = "github:clash-lang/clash-compiler";
    nixpkgs.follows = "clash-compiler/nixpkgs";
  };
  outputs = { self, flake-utils, nixpkgs, clash-compiler, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # The package to expose as 'default'
        default-package = "clash-shockwaves";
        # The 'default' version of ghc to use
        default-version = clash-compiler.ghcVersion.${system};
        # A list of all ghc versions this package supports
        supported-versions = clash-compiler.supportedGhcVersions.${system};

        generic-pkgs = import nixpkgs {
          inherit system;
        };

        all-overlays = builtins.listToAttrs (builtins.map (compiler-version:
          let
            overlay = final: prev: {
              clash-shockwaves = prev.developPackage {
                root = ./clash-shockwaves;
                overrides = _: _: final;
              };
            };
          in
            { name = compiler-version; value = overlay; }
          ) supported-versions);

        all-hs-pkgs = builtins.mapAttrs (compiler-version: overlay:
          let
            pkgs = (import clash-compiler.inputs.nixpkgs {
              inherit system;
            }).extend clash-compiler.overlays.${compiler-version};
            clash-pkgs = pkgs."clashPackages-${compiler-version}";

            hs-pkgs = clash-pkgs.extend overlay;
          in
            hs-pkgs
          ) all-overlays;

        all-shells = builtins.mapAttrs (_: hs-pkgs:
          hs-pkgs.shellFor {
            packages = p: [
              p.clash-shockwaves
            ];

            nativeBuildInputs =
              [
                # Haskell stuff
                hs-pkgs.cabal-install
                hs-pkgs.cabal-plan
                hs-pkgs.haskell-language-server
                hs-pkgs.fourmolu

                # For the Rust package
                # NOTE: we do not build the Rust package, simply provide an environment that can be
                # used to compile it with
                generic-pkgs.cargo
                generic-pkgs.clippy
                generic-pkgs.rust-analyzer
                generic-pkgs.lld # Required for the wasm32-unknown-unknown target
              ]
            ;
          }) all-hs-pkgs;

        all-packages = builtins.mapAttrs (_: hs-pkgs:
          {
            clash-shockwaves = hs-pkgs.clash-shockwaves;

            default = hs-pkgs.${default-package};
          }) all-hs-pkgs;
      in
      {
        # Expose the overlay of each supported version which adds clash-shockwaves
        # The base of the overlay is clash-pkgs
        overlays = all-overlays // { default = all-overlays.${default-version}; };

        # A devShell for each supported version
        devShells = all-shells // { default = all-shells.${default-version}; };

        # The default directly refers to the default package of the default ghc version of this flake
        # All other entries aren't packages, they're a set of packages for each supported ghc version
        packages = all-packages // { default = all-packages.${default-version}.${default-package}; };
      });
}
