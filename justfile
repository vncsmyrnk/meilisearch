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
