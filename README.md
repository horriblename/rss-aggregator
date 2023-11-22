# RSS Aggregator

An RSS Aggregator webapp

![rss-aggre-screenshot](attachments/rss-aggre-screenshot.png)

## Deployment

### via Docker

```bash
cd deploy && docker-compose up
```

### via NixOS Module

with flakes:

```nix
{
   inputs.rss-aggre.url = "github:horriblename/rss-aggregator";
   outputs = inputs: {
      nixosConfigurations.hostname = let
         inherit (inputs.nixpkgs) lib;
         system = "x86_64-linux";
      in lib.nixosSystem {
         inherit system;
         pkgs = import nixpkgs {
            inherit system;
            overlays = [inputs.rss-aggre.overlays.default];
         };

         modules = [
            inputs.rss-aggre.nixosModules.default
            {services.rss-aggre.enable = true;}
         ];
      };
   };
}
```
