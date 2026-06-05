{ pkgs ? import <nixpkgs> {} }:

# let
#   tex = pkgs.texlive.combine {
#     inherit (pkgs.texlive)
#       scheme-full
#       beamer;
#   };
pkgs.mkShell {
  buildInputs = with pkgs; [
  texliveFull
  quarto

    (rWrapper.override {
      packages = with rPackages; [
        languageserver
      ];
    })
  ];
}
