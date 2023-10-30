{
  description = "A very basic flake";
  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;
    eachSystem = lib.genAttrs ["x86_64-linux"];
    pkgsFor = eachSystem (
      system:
        import nixpkgs {
          localSystem = system;
          overlays = [self.overlays.default];
        }
    );
  in {
    overlays = {
      default = final: prev: {
        rss-aggre = final.callPackage ./rss-aggre.nix {};
      };
    };

    packages = eachSystem (system: {
      default = self.packages.${system}.rss-aggre;
      inherit (pkgsFor.${system}) rss-aggre;
    });
    devShells = eachSystem (system: let
      pkgs = pkgsFor.${system};
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = with pkgs;
        with elmPackages; [
          go
          postgresql_15
          sqlc
          goose
          luajit
          luajitPackages.http
          luajitPackages.cjson
          luajitPackages.fennel
          elm
          elm-language-server
          elm-format
          elm-test
          elm-live
        ];
      };
    });
  };
}
