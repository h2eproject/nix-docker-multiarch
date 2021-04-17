# nix-docker-multiarch
## Build multi-arch Docker images using Nix

For a usage example, see `usage-example.nix`.

To build and push the containers, run `nix run -f usage-example.nix -c push`.

## CI

Copy the GitHub Actions workflow from `.github/workflows/publish.yml` and customize based on what images you'd like to build.
