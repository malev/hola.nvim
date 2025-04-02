{
  description = "hola.nvim's flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        hola-nvim = pkgs.vimUtils.buildVimPlugin {
          pname = "hola-nvim";
          version = self.shortRev or "dirty";
          src = self;
          doCheck = false;
        };
        plenaryPlugin = pkgs.vimPlugins.plenary-nvim;
      in
      {
        packages = {
          ${hola-nvim.pname} = hola-nvim;
          plenary = plenaryPlugin;
          default = hola-nvim;
        };
        defaultPackage = self.packages.${system}.default;
        nvimPlugins = {
          "hola-nvim" = hola-nvim;
          "plenary-nvim" = plenaryPlugin;
        };
      });
}
