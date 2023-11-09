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
        webclient = final.callPackage ./webclient {};
      };
    };

    packages = eachSystem (system: {
      default = self.packages.${system}.rss-aggre;
      inherit (pkgsFor.${system}) rss-aggre webclient;
      dockerStream = with pkgsFor.${system};
        dockerTools.streamLayeredImage {
          name = "rss-aggre";
          tag = "latest";

          # I don't wanna deal with TLS certs so I'm stealing them from alpine :p
          fromImage = dockerTools.pullImage {
            imageName = "alpine";
            imageDigest = "sha256:f3334cc04a79d50f686efc0c84e3048cfb0961aba5f044c7422bd99b815610d3";
            sha256 = "sha256-snYCbJocC3VLcVvOJzlujtHcJAHJHExhxoq/9r3yYvI=";
          };

          # copyToRoot = buildEnv {
          #   name = "rss-aggre";
          #   pathsToLink = ["/bin"];
          #   paths = [
          #   ];
          # };

          contents = [self.packages.${system}.rss-aggre];

          config = {
            Cmd = ["/bin/rss-aggre"];
            ExposedPorts = {
              "80" = {};
              "443" = {};
            };
            Env = [
              "PORT=80"

              # formatted as a psql connection string
              # https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING
              ''DATABASE_URL="user=rss-aggre host=localhost port=5432"''

              # Path to file containing db password; can be used alongside DATABASE_URL
              # This is intended to be used in conjunction with docker secrets
              # example: "/run/secrets/db_password.txt"
              "DATABASE_PASSWORD_FILE=''"
            ];
            Entrypoint = [
            ];
          };
        };
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
