default:
  just --list

conventional-docker-build:
  docker build -t meilisearch-local-buildx .

nix-docker-build:
  nix build .#default -L --cores 2 # increase the job numbers if more ram is available
  docker load < result

run-conventional-docker-build:
  docker run -it --rm \
    -p 7700:7700 \
    meilisearch-local-buildx:latest

run-nix-docker-build:
  docker run -it --rm \
    -p 7700:7700 \
    meilisearch-local-nix:latest

generate-sboms:
  syft ghcr.io/vncsmyrnk/meilisearch-nix:latest -o spdx-json | jq > /tmp/meilisearch-nix-sbom.spdx.json
  syft ghcr.io/vncsmyrnk/meilisearch-traditional:latest -o spdx-json | jq > /tmp/meilisearch-traditional-sbom.spdx.json

scan-vulnerabilities: generate-sboms
  @echo 'Scanning the nix built image...'
  cat /tmp/meilisearch-nix-sbom.spdx.json | grype
  @echo 'Now scanning the traditional built one...'
  cat /tmp/meilisearch-traditional-sbom.spdx.json | grype
