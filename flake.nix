{
  description = "My hakyll website";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    hix = {
      url = "github:tek/hix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cv = {
      url = "github:mrcjkb/cv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {self, ...}:
    inputs.hix ({
      config,
      lib,
      ...
    }: let
      sourceFilter = root: with lib.fileset; toSource {
        inherit root;
        fileset = fileFilter (file: lib.any file.hasExt [ "cabal" "hs" "md" ]) root;
      };
      pname = "mrcjkbs-site";
      system = config.pkgs.system;
      cv-pkg = inputs.cv.packages.${system}.default;
    in {
      compiler = "ghc96";
      cabal = {
        author = "Marc Jakobi";
        build-type = "Simple";
        # license = "GPL-2.0-or-later"; TODO?
        # license-file = "LICENCE.md";
        version = "1.0.0.0";
        meta = {
          maintainer = "marc@jakobi.dev";
          homepage = "mrcjkb.dev";
          synopsis = "My Hakyll site";
        };
        language = "GHC2021";
        default-extensions = [
          "ApplicativeDo"
          "BlockArguments"
          "DataKinds"
          "DefaultSignatures"
          "DeriveAnyClass"
          "DeriveGeneric"
          "DerivingVia"
          "ExplicitNamespaces"
          "LambdaCase"
          "NoImplicitPrelude"
          "OverloadedLabels"
          "OverloadedStrings"
          "PackageImports"
          "RecordWildCards"
          "StrictData"
          "TypeFamilies"
          "ViewPatterns"
        ];
        ghc-options = [
          "-Weverything"
          "-Wno-unsafe"
          "-Wno-missing-safe-haskell-mode"
          "-Wno-missing-export-lists"
          "-Wno-missing-import-lists"
          "-Wno-missing-kind-signatures"
          "-Wno-all-missed-specialisations"
        ];
      };
      packages.${pname} = {
        src = sourceFilter ./.;
        executable = {
          enable = true;
          source-dirs = "app";
          dependencies = [
            "hakyll"
            "pandoc"
          ];
        };
      };
      envs.dev = {
        env.DIRENV_IN_ENVRC = "";
        setup-pre =
          ''
            NIX_MONITOR=disable nix run .#gen-cabal
            NIX_MONITOR=disable nix run .#tags
          ''
          + self.checks.${system}.git.shellHook;
        buildInputs = self.checks.${system}.git.enabledPackages;
      };
      outputs = {
        packages = with config; let
          site-pkg = self.packages.${system}.default;
        in {
          website = pkgs.stdenv.mkDerivation {
            name = "website";
            buildInputs = [];
            src =
              pkgs.nix-gitignore.gitignoreSourcePure [
                ./.gitignore
                ".git"
                ".github"
              ]
              self;
            # LANG and LOCALE_ARCHIVE are fixes pulled from the community:
            #   https://github.com/jaspervdj/hakyll/issues/614#issuecomment-411520691
            #   https://github.com/NixOS/nix/issues/318#issuecomment-52986702
            #   https://github.com/MaxDaten/brutal-recipes/blob/source/default.nix#L24
            LANG = "en_US.UTF-8";
            LOCALE_ARCHIVE =
              pkgs.lib.optionalString
              (pkgs.stdenv.buildPlatform.libc == "glibc")
              "${pkgs.glibcLocales}/lib/locale/locale-archive";

            buildPhase = ''
              runHook preBuild
              mkdir files
              cp ${cv-pkg}/* files/
              ${lib.getExe site-pkg} build --verbose
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/dist"
              cp -a _site/. "$out/dist"
              runHook postInstall
            '';
          };
        };
        checks = {
          git = inputs.git-hooks.lib.${system}.run {
            src = self;
            hooks = {
              alejandra.enable = true;
            };
          };
        };
      };
    });
}
