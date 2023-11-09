{
  stdenvNoCC,
  elm,
  uglify-js,
}:
stdenvNoCC.mkDerivation {
  name = "RSS Agreggator web client";
  version = "0.1";

  src = ./.;

  nativeBuildInputs = [
    elm
    uglify-js
  ];

  configurePhase = ''
    export PREFIX=$out
  '';
}
