{
  description = "My hakyll website";

  nixConfig = {
    allow-import-from-derivation = "true";
    # TODO: Migrate to cabal2nix
    extra-substituters = [
      "https://cache.iog.io"
      "https://cache.zw3rk.com" # https://github.com/input-output-hk/haskell.nix/issues/1408
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
    ];
  };

  inputs = {
    haskellNix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    haskellNix,
    flake-utils,
    pre-commit-hooks,
  }: let
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  in
    flake-utils.lib.eachSystem supportedSystems (
      system: let
        overlay = self: _: {
          hsPkgs = self.haskell-nix.project' {
            src = builtins.path {
              path = ./.;
              name = "mrcjkbs-site";
            };
            compiler-nix-name = "ghc925";
            shell = {
              buildInputs = [
                mrcjkbs-site
              ];
              tools = {
                cabal = "latest";
                hlint = "latest";
                haskell-language-server = "latest";
              };
            };
          };
        };

        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            haskellNix.overlay
            overlay
          ];
        };

        flake = pkgs.hsPkgs.flake {};

        mrcjkbs-site = flake.packages."mrcjkbs-site:exe:site";

        website = pkgs.stdenv.mkDerivation {
          name = "website";
          buildInputs = [];
          src =
            pkgs.nix-gitignore.gitignoreSourcePure [
              ./.gitignore
              ".git"
              ".github"
            ]
            ./.;
          # LANG and LOCALE_ARCHIVE are fixes pulled from the community:
          #   https://github.com/jaspervdj/hakyll/issues/614#issuecomment-411520691
          #   https://github.com/NixOS/nix/issues/318#issuecomment-52986702
          #   https://github.com/MaxDaten/brutal-recipes/blob/source/default.nix#L24
          LANG = "en_US.UTF-8";
          LOCALE_ARCHIVE =
            pkgs.lib.optionalString
            (pkgs.buildPlatform.libc == "glibc")
            "${pkgs.glibcLocales}/lib/locale/locale-archive";

          buildPhase = ''
            ${mrcjkbs-site}/bin/site build --verbose
          '';

          installPhase = ''
            mkdir -p "$out/dist"
            cp -a _site/. "$out/dist"
          '';
        };
      in
        flake
        // {
          packages = {
            default = website;
            inherit mrcjkbs-site website;
          };
          apps.default = flake-utils.lib.mkApp {
            drv = mrcjkbs-site;
            exePath = "/bin/site";
          };
          checks = {
            pre-commit = pre-commit-hooks.lib.${system}.run {
              src = self;
              hooks = {
                alejandra.enable = true;
              };
            };
          };
        }
    );
}
