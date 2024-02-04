{
  description = "Example kickstart Elm application project.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; }
      {
        systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
        perSystem = { config, self', inputs', pkgs, system, lib, ... }:
          let
            inherit (pkgs) elmPackages nodePackages stdenv;
            name = "example";
          in
          {
            devShells = {
              default = pkgs.mkShell {
                inputsFrom = [ self'.packages.default ];
                buildInputs = with pkgs; [ elm2nix ];
              };
            };

            packages = {
              default =
                let
                  mkDerivation =
                    { srcs ? ./elm-srcs.nix
                    , src
                    , name
                    , srcdir ? "./src"
                    , targets ? [ ]
                    , registryDat ? ./registry.dat
                    , outputJavaScript ? false
                    }:
                    stdenv.mkDerivation {
                      inherit name src;

                      buildInputs = [ elmPackages.elm ]
                        ++ lib.optional outputJavaScript nodePackages.uglify-js;

                      buildPhase = pkgs.elmPackages.fetchElmDeps {
                        elmPackages = import srcs;
                        elmVersion = "0.19.1";
                        inherit registryDat;
                      };

                      installPhase =
                        let
                          elmfile = module: "${srcdir}/${builtins.replaceStrings ["."] ["/"] module}.elm";
                          extension = if outputJavaScript then "js" else "html";
                        in
                        ''
                          mkdir -p $out/share/doc
                          ${lib.concatStrings (map (module: ''
                                      echo "compiling ${elmfile module}"
                                      elm make ${elmfile module} --output $out/${module}.${extension} --docs $out/share/doc/${module}.json
                                      ${lib.optionalString outputJavaScript ''
                                      echo "minifying ${elmfile module}"
                                      uglifyjs $out/${module}.${extension} --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' \
                                      | uglifyjs --mangle --output $out/${module}.min.${extension}
                                      ''}
                                      '') targets)}
                        '';
                    };
                in
                mkDerivation {
                  inherit name;
                  srcs = ./elm-srcs.nix;
                  src = ./.;
                  targets = [ "Main" ];
                  srcdir = "./src";
                  outputJavaScript = false;
                };
            };
          };
      };
}
