{buildGoModule}:
buildGoModule {
  pname = "rss-aggre";
  version = "0.1";

  src = ../.;
  vendorHash = "sha256-lX+5edOBfwmuik8C3+OPLlizR3iDg7VK+Ov0gh4BRM8=";

  meta = {
    mainProgram = "rss-aggre";
  };
}
