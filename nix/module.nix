{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) types;
  cfg = config.services.rss-aggre;
in {
  options.services.rss-aggre = {
    enable = lib.mkEnableOption "RSS aggregator service";

    package = lib.mkOption {
      description = "RSS Aggregator package";
      type = types.package;
      default = pkgs.rss-aggre;
    };

    goosePackage = lib.mkOption {
      description = "Goose package, used for database migrations";
      type = types.package;
      default = pkgs.goose;
    };

    port = lib.mkOption {
      description = "RSS Aggragator server port";
      type = types.port;
      default = 12080;
    };

    postgres = {
      # user = lib.mkOption {
      #   description = "Postgres Database user";
      #   type = types.str;
      #   default = "rss-aggre";
      # };
      dbName = lib.mkOption {
        description = "The database name to use";
        type = types.str;
        default = "rss-aggre";
      };
      # passwordFile = lib.mkOption {
      #   description = "Path to file containing database password";
      #   type = types.str;
      #   default = "";
      # };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      pgUser = "rss-aggre";
      # unix socket seems to be called /var/run/postgres (without '...ql')
      connString = "user=${pgUser} host=/var/run/postgresql dbname=${cfg.postgres.dbName}";
    in {
      services.postgresql = {
        enable = true;
        # ensureUsers uses peer authentication: checks OS username against DB username (local only)
        ensureUsers = [
          {name = pgUser;}
        ];
        ensureDatabases = [cfg.postgres.dbName];
      };

      users.users.rss-aggre = {
        isNormalUser = true;
        name = "rss-aggre";
        group = "rss-aggre";
        description = "RSS Aggregator server user";
        useDefaultShell = true;
      };
      users.groups.rss-aggre = {};

      environment.systemPackages = [cfg.package];

      systemd.services.rss-aggre-db-migration = {
        description = "RSS Aggregator Database Migration";
        wantedBy = ["multi-user.target"];
        after = ["rss-aggre.target"];

        path = [cfg.goosePackage];
        serviceConfig = {
          User = "rss-aggre";
          Group = "rss-aggre";
          Type = "oneshot";
          WorkingDirectory = "${cfg.package}/share/rss-aggre/schema";
          ExecStart = pkgs.writeShellScript "rss-aggre-migration-script" ''
            set -e
            connString='${connString}'

            exec goose postgres "$connString" up
          '';
        };
      };

      systemd.services.rss-aggre = {
        description = "RSS Aggregator Server";
        wantedBy = ["multi-user.target"];
        after = ["postgresql.target"];
        environment = {
          PORT = toString cfg.port;
          DATABASE_URL = connString;
        };

        path = [cfg.package];
        serviceConfig = {
          User = "rss-aggre";
          Group = "rss-aggre";
          Type = "exec";

          TimeoutSec = 120;

          ExecStart = "${lib.getExe cfg.package}";
        };
      };
    }
  );
}
