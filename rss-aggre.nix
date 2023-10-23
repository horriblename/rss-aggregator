{
  go,
  stdEnvNoCC,
}:
stdEnvNoCC.mkDerivation {
  pname = "rss-aggre";
  version = "0.1";
  src = ./.;

  nativeBuildInputs = [go];
}
