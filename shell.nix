{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
  texliveFull
  quarto

    (rWrapper.override {
      packages = with rPackages; [
        languageserver
        mlogit
      ];
    })
  ];
}
