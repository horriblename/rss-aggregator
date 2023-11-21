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
        rss-aggre = final.callPackage ./nix/rss-aggre.nix {};
        rss-aggre-webclient = final.callPackage ./webclient {};
      };
    };

    nixosModules.default = import ./nix/module.nix;

    packages = eachSystem (system: {
      default = self.packages.${system}.rss-aggre;
      inherit (pkgsFor.${system}) rss-aggre rss-aggre-webclient;
      dockerStream = pkgsFor.${system}.callPackage ./nix/rssAggreDockerStream.nix {};
      # Image with goose installed, doesn't do anything by default
      gooseImageStream = pkgsFor.${system}.callPackage ./nix/gooseDockerStream.nix {};
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
          nodePackages.uglify-js
        ];
      };
    });
  };
}
