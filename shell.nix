{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    texliveFull
    julia

    (rWrapper.override {
      packages = with rPackages; [
        languageserver
        quarto
        JuliaCall
        mlogit
      ];
    })
  ];

  shellHook = ''
    alias render="Rscript -e 'quarto::quarto_render(\"Slides.qmd\")'"
  '';
}
