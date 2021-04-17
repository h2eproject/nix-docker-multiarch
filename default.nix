{ name ? "ghcr.io/h2eproject/nix-docker-multiarch"
, cmd ? ({ hello }: "${hello}/bin/hello"), tagBase ? "latest"
, nixpkgs ? import <nixpkgs>, config ? { } }:

let
  pkgs = nixpkgs { };
  lib = pkgs.lib;
  buildImage = arch:
    { dockerTools, callPackage }:
    dockerTools.buildImage {
      inherit name;
      tag = "${tagBase}-${arch}";
      config = {
        Cmd = [ (callPackage cmd { }) ];
      } // config;
    };
  architectures = [ "x86_64" "aarch64" ];
  crossSystems = map (arch: {
    inherit arch;
    pkgs = if pkgs.system == "${arch}-linux" then
      pkgs
    else
      nixpkgs { crossSystem = { config = "${arch}-linux"; }; };
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
