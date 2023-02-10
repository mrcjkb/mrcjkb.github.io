{
  description = "My hakyll website";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    hakyll-flakes = {
      url = "github:Radvendii/hakyll-flakes";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    hakyll-flakes,
    flake-utils,
    pre-commit-hooks,
  }: let
    supportedSystems = ["x86_64-linux"];
  in
    flake-utils.lib.eachSystem supportedSystems (
      system:
        hakyll-flakes.lib.mkAllOutputs {
          inherit system;
          name = "my-hakyll-website";
          src = ./.;
          websiteBuildInputs = with nixpkgs.legacyPackages.${system}; [
            rubber
            texlive.combined.scheme-full
            poppler_utils
          ];
        }
    )
    // flake-utils.lib.eachSystem supportedSystems (
      system: {
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
