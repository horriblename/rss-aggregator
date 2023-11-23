{
  buildGoModule,
  lib,
}: let
  inherit (lib.sources) cleanSourceWith cleanSourceFilter;

  src = cleanSourceWith {
    filter = cleanSourceFilter;
    src = cleanSourceWith {
      filter = name: _type: ! (lib.hasSuffix ".nix" (toString name));
      src = ../.;
    };
  };
in
  buildGoModule {
    pname = "rss-aggre";
    version = "0.1";

    inherit src;

    vendorHash = "sha256-xtmd0V/YkxR9LHhml/Mrefuv+Ym19FiTYlmRh7aHK2A=";

    outputs = ["out"];

    postInstall = ''
      mkdir -p $out/share/rss-aggre
      cp -r ${src}/sql/schema $out/share/rss-aggre
    '';

    meta = {
      mainProgram = "rss-aggre";
    };
  }
