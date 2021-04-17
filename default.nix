{ name ? "ghcr.io/h2eproject/nix-docker-multiarch"
, cmd ? ({ hello }: "${hello}/bin/hello"), tagBase ? "latest", nixpkgs ? import
  (builtins.fetchTarball
    "https://releases.nixos.org/nixos/unstable/nixos-21.05pre282843.dcdf30a78a5/nixexprs.tar.xz")
}:

let
  pkgs = nixpkgs { };
  lib = pkgs.lib;
  buildImage = arch:
    { callPackage }:
    pkgs.dockerTools.buildImage {
      inherit name;
      tag = "${tagBase}-${arch}";
      config = { Cmd = [ (callPackage cmd { }) ]; };
    };
  architectures = [ "i686" "x86_64" "aarch64" "powerpc64le" ];
  crossSystems = map (arch: {
    inherit arch;
    pkgs = (nixpkgs {
      crossSystem = { config = "${arch}-unknown-linux-musl"; };
    }).pkgsStatic;
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
