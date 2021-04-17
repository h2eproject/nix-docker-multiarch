{ name ? "ghcr.io/h2eproject/nix-docker-multiarch"
, cmd ? ({ hello }: "${hello}/bin/hello"), tagBase ? "latest", nixpkgs ? import
  (builtins.fetchTarball
    "https://github.com/h2eproject/nixpkgs/archive/refs/heads/piper/add-docker-arm-variant-support.tar.gz")
, config ? { } }:

let
  pkgs = nixpkgs { };
  lib = pkgs.lib;
  muslSupported = arch:
    arch == "i686" || arch == "x86_64" || arch == "aarch64" || arch
    == "powerpc64le";
  legacyArm = arch: arch == "armv5tel" || arch == "armv6l" || arch == "armv7l";
  buildImage = arch:
    { dockerTools, callPackage, pkgsStatic }:
    dockerTools.buildImage {
      inherit name;
      tag = "${tagBase}-${arch}";
      config = {
        Cmd = [
          ((if muslSupported arch then pkgsStatic.callPackage else callPackage)
            cmd { })
        ];
      } // config;
    };
  architectures = [ "i686" "x86_64" "armv5tel" "armv6l" "armv7l" "aarch64" ];
  crossSystems = map (arch: {
    inherit arch;
    pkgs = nixpkgs {
      crossSystem = {
        config = "${arch}-unknown-linux-${
            if muslSupported arch then
              "musl"
            else if legacyArm arch then
              "gnueabi"
            else
              "gnu"
          }";
      };
    };
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
