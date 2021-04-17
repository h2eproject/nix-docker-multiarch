{ name ? "ghcr.io/h2eproject/nix-docker-multiarch-example", tagBase ? "latest" }:
let docker = import ./default.nix;
  # Use this to include from other projects
  dockerFromGit = import (builtins.fetchGit {
      url = "https://github.com/h2eproject/nix-docker-multiarch";
      ref = "main";
    });
in docker {
  # The name of the image
  inherit name;
  # What to tag the image with. Additional architecture-specific images will be generated
  # prefixed with tagBase. (e.g. latest-x86_64)
  inherit tagBase;
  # The command to run in the image.
  cmd = { python3 }: "${python3}/bin/python3";
  # Additional configuration for the image
  # See https://github.com/moby/moby/blob/master/image/spec/v1.2.md#container-runconfig-field-descriptions
  config = {
    Env = [
      "NIX_DOCKER_MULTIARCH=\"true\""
    ];
  };
}
