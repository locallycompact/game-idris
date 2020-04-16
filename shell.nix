{ pkgs ? import <nixpkgs> {} }:

with pkgs;
pkgs.mkShell {
  buildInputs = [ 
    (pkgs.idrisPackages.with-packages( with pkgs.idrisPackages; [
      box2d
      containers
      contrib
      sdl2
    ]))
  ];
}
