{
  buildGoModule,
  lib,
}: let
  inherit (lib.sources) cleanSourceWith cleanSourceFilter;
in
  buildGoModule {
    pname = "rss-aggre";
    version = "0.1";

    src = cleanSourceWith {
      filter = cleanSourceFilter;
      src = cleanSourceWith {
        filter = name: _type: ! (lib.hasSuffix ".nix" (toString name));
        src = ../.;
      };
    };

    vendorHash = "sha256-lX+5edOBfwmuik8C3+OPLlizR3iDg7VK+Ov0gh4BRM8=";

    outputs = ["out"];

    migrations = ../sql/schema;

    meta = {
      mainProgram = "rss-aggre";
    };
  }
