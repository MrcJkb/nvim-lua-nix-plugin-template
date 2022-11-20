{
  description = "Neovim Nix flake CI template for GitHub Actions"; # TODO: Set description

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    # TODO: Add imports for tests here

    packer-nvim = {
      url = "github:wbthomason/packer.nvim";
      flake = false;
    };

    plenary-nvim = {
      url = "github:nvim-lua/plenary.nvim";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, pre-commit-hooks, packer-nvim, plenary-nvim, ... }:
    let

      name = "plugin-template.nvim"; # TODO: Choose a name

      supportedSystems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      perSystem = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };

      ci-overlay = import ./nix/ci-overlay.nix { inherit (inputs) packer-nvim plenary-nvim; }; # TODO: Add test inputs as arguments here
      nvim-plugin-overlay = import ./nix/nvim-plugin-overlay.nix { inherit name; self = ./.; };

      nvim-plugin-for = system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.vimUtils.buildVimPluginFrom2Nix {
          inherit name;
          src = ./.;
        };

      pre-commit-check-for = system: pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          nixpkgs-fmt.enable = true;
          stylua.enable = true;
          # TODO: Add additional formatting checks here
        };
      };

      shellFor = system:
        let
          pkgs = pkgsFor system;
          pre-commit-check = pre-commit-check-for system;
        in
        pkgs.mkShell {
          name = "devShell"; # TODO: Choose a name
          inherit (pre-commit-check) shellHook;
          buildInputs = with pkgs; [
            zlib
          ];
        };
    in
    {
      overlays = {
        inherit ci-overlay nvim-plugin-overlay;
        default = nvim-plugin-overlay;
      };

      devShells = perSystem (system: rec {
        default = devShell;
        devShell = shellFor system;
      });

      packages = perSystem (system: rec {
        default = nvim-plugin;
        nvim-plugin = nvim-plugin-for system;
      });

      checks = perSystem (system:
        let
          checkPkgs = import nixpkgs { inherit system; overlays = [ ci-overlay ]; };
        in
        {
          formatting = pre-commit-check-for system;
          inherit (checkPkgs) ci;
        });
    };
}
