{
  description = "shen-cl — Nix-managed Common Lisp development environment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
      each = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      tools = pkgs: [ pkgs.sbcl pkgs.clisp pkgs.ecl pkgs.gnumake pkgs.git pkgs.curl pkgs.gnutar pkgs.gzip ];
    in {
      packages = each (pkgs: {
        toolchain = pkgs.buildEnv { name = "shen-cl-toolchain"; paths = tools pkgs; };
        default = pkgs.buildEnv { name = "shen-cl-toolchain"; paths = tools pkgs; };
      });
      devShells = each (pkgs: { default = pkgs.mkShell { packages = tools pkgs; }; });
    };
}
