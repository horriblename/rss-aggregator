{
  dockerTools,
  rss-aggre,
}:
dockerTools.streamLayeredImage {
  name = "horriblename/rss-aggre";
  tag = "latest";

  # I don't wanna deal with TLS certs so I'm stealing them from alpine :p
  fromImage = dockerTools.pullImage {
    imageName = "alpine";
    imageDigest = "sha256:f3334cc04a79d50f686efc0c84e3048cfb0961aba5f044c7422bd99b815610d3";
    sha256 = "sha256-snYCbJocC3VLcVvOJzlujtHcJAHJHExhxoq/9r3yYvI=";
  };

  contents = [rss-aggre];

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
}
