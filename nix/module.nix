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
      connString = "user=${pgUser} host=${config.services.postgresql.dataDir} dbname=${cfg.postgres.dbName}";
      rssAggrePort = "12080";
    in {
      services.postgresql = {
        enable = true;
        # ensureUsers uses peer authentication: checks OS username against DB username (local only)
        ensureUsers = [
          {name = pgUser;}
        ];
      };

      services.caddy.configFile = ''
        reverse_proxy :80 ${rssAggrePort}
      '';

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

        path = [cfg.goosePackage cfg.package.migrations];
        serviceConfig = {
          User = "rss-aggre";
          Group = "rss-aggre";
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "rss-aggre-migration-script" ''
            set -e
            cd ${cfg.package.migrations}
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
          PORT = rssAggrePort;
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
