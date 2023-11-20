{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) types;
  cfg = config.options.services.rss-aggre;
in {
  options.services.rss-aggre = {
    enable = lib.mkEnableOption "RSS aggregator service";
    databaseUser = lib.mkOption {
      description = "Postgres Database user";
      type = types.str;
      default = "rss-aggre";
    };
    databasePasswordFile = lib.mkOption {
      description = "Path to file containing database password";
      type = types.str;
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql.enable = true;
    services.postgresql.package = pkgs.postgresql_15;

    users.users.rss-aggre = {
      name = "rss-aggre";
      group = "rss-aggre";
      description = "RSS Aggregator server user";
      useDefaultShell = true;
    };

    environment.systemPackages = [pkgs.rss-aggre];

    systemd.services.rss-aggre-db-migration = {
      description = "RSS Aggregator Database Migration";
      wantedBy = ["multi-user.target"];
      after = ["rss-aggre.target"];

      path = [pkgs.goose];
      serviceConfig = {
        User = "rss-aggre";
        Group = "rss-aggre";
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript ''
          DB_PASSWORD="$(cat ${cfg.databasePasswordFile} | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g")"
          DB_URL="user=${cfg.databaseUser} host=localhost port=5432 password='$DB_PASSWORD' sslmode=disable"

          exec goose postgres "$DB_URL" up
        '';
      };
    };

    systemd.services.rss-aggre = {
      description = "RSS Aggregator Server";
      wantedBy = ["multi-user.target"];
      after = ["postgresql.target"];

      path = [pkgs.rss-aggre];
      serviceConfig = {
        User = "rss-aggre";
        Group = "rss-aggre";
        Type = "exec";

        TimeoutSec = 120;

        ExecStart = "${lib.getExe pkgs.rss-aggre}";
      };
    };
  };
}
