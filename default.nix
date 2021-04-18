{ name ? "ghcr.io/h2eproject/nix-docker-multiarch"
, cmd ? ({ hello }: "${hello}/bin/hello"), tagBase ? "latest"
, pkgs ? import <nixpkgs> { }, config ? { } }:

let
  lib = pkgs.lib;
  buildImage = arch:
    { dockerTools, callPackage }:
    dockerTools.buildImage {
      inherit name;
      tag = "${tagBase}-${arch}";
      config = { Cmd = [ (callPackage cmd { }) ]; } // config;
    };
  architectures = {
    "x86_64" = pkgs.pkgsCross.gnu64;
    "aarch64" = pkgs.pkgsCross.aarch64-multiplatform;
  };
  crossSystems = lib.mapAttrsToList (arch: cross: {
    inherit arch;
    pkgs = if pkgs.system == "${arch}-linux" then pkgs else cross;
  }) architectures;
  images = map ({ arch, pkgs }: rec {
    inherit arch;
    image = pkgs.callPackage (buildImage arch) { };
    tag = "${tagBase}-${arch}";
  }) crossSystems;
  loadAndPush = builtins.concatStringsSep "\n" (lib.concatMap
    ({ arch, image, tag }: [
      "$docker load -i ${image}"
      "$docker push ${name}:${tag}"
    ]) images);
  imageNames = builtins.concatStringsSep " "
    (map ({ arch, image, tag }: "${name}:${tag}") images);

in pkgs.writeTextFile {
  inherit name;
  text = ''
    #!${pkgs.stdenv.shell}
    set -euxo pipefail
    docker=${pkgs.docker}/bin/docker
    ${loadAndPush}
    $docker manifest create --amend ${name}:${tagBase} ${imageNames}
    $docker manifest push ${name}:${tagBase}
  '';
  executable = true;
  destination = "/bin/push";
}
