# based on elm2nix
{
  stdenv,
  lib,
  elmPackages,
  nodePackages,
  apiBaseUrl ? "https://rss-aggre.horriblename.site",
}: let
  apiUrlFile = ''
    module ApiUrl exposing (apiBaseUrl)


    apiBaseUrl : String
    apiBaseUrl =
        "${apiBaseUrl}"
  '';
  mkDerivation = {
    srcs ? ./elm-srcs.nix,
    src,
    name,
    srcdir ? "./src",
    targets ? [],
    registryDat ? ./registry.dat,
    outputJavaScript ? false,
    htmlEntrypoint ? null,
  }:
    stdenv.mkDerivation {
      inherit name src;

      buildInputs =
        [elmPackages.elm]
        ++ lib.optional outputJavaScript nodePackages.uglify-js;

      buildPhase = elmPackages.fetchElmDeps {
        elmPackages = import srcs;
        elmVersion = "0.19.1";
        inherit registryDat;
      };

      # used by ./configure
      API_URL_FILE_CONTENT = apiUrlFile;

      configureScript = ''
        if [ -n "$API_URL_FILE_CONTENT" ]; then
        	echo "$API_URL_FILE_CONTENT" > src/ApiUrl.elm
        fi
      '';

      installPhase = let
        elmfile = module: "${srcdir}/${builtins.replaceStrings ["."] ["/"] module}.elm";
        extension =
          if outputJavaScript
          then "js"
          else "html";
      in ''
        mkdir -p $out/share/doc
        ${lib.concatStrings (map (module: ''
            echo "compiling ${elmfile module}"
            elm make ${elmfile module} --optimize --output $out/${module}.${extension} --docs $out/share/doc/${module}.json
            ${lib.optionalString outputJavaScript ''
              echo "minifying ${elmfile module}"
              uglifyjs $out/${module}.${extension} --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' \
                  | uglifyjs --mangle --output $out/${module}.${extension}
            ''}
            ${lib.optionalString (htmlEntrypoint != null) ''
              cp ${htmlEntrypoint} $out
            ''}
          '')
          targets)}
      '';
    };
in
  mkDerivation {
    name = "elm-app-0.1.0";
    srcs = ./elm-srcs.nix;
    src = ./.;
    targets = ["Main"];
    srcdir = "./src";
    outputJavaScript = true;
    htmlEntrypoint = "index.html";
  }
