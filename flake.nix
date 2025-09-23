{
  description = "Meilisearch Docker image";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
      version = cargoToml.workspace.package.version;

      # Build arguments that can be overridden
      commitSha = builtins.getEnv "COMMIT_SHA";
      commitDate = builtins.getEnv "COMMIT_DATE";
      gitTag = builtins.getEnv "GIT_TAG";

      rustSrc = pkgs.lib.cleanSourceWith {
        src = ./.;
        filter = path: type:
          let baseName = baseNameOf (toString path);
          in !(
            # Exclude Nix files, git directory, and build outputs
            (baseName == "flake.nix") || (baseName == "flake.lock")
            || (baseName == ".git") || (baseName == "result")
            || (baseName == "justfile"));
      };

      # Build the Rust application
      meilisearch = pkgs.rustPlatform.buildRustPackage {
        pname = "meilisearch";
        version = version;
        src = rustSrc;

        cargoHash = "sha256-Vcb58ANpDlMdCvkdAe4mu2gYC+fdiqPT1PO7s32e2Ck=";

        nativeBuildInputs = with pkgs; [ pkg-config ];
        buildInputs = [ ];

        # Set environment variables for build
        VERGEN_GIT_SHA = commitSha;
        VERGEN_GIT_COMMIT_TIMESTAMP = commitDate;
        VERGEN_GIT_DESCRIBE = gitTag;
        RUSTFLAGS = "-C target-feature=-crt-static";

        # Build specific packages
        cargoBuildFlags = [ "-p" "meilisearch" "-p" "meilitool" ];

        # Disable features that require network downloads during build
        buildNoDefaultFeatures = true;
        buildFeatures = [ ];

        # Skip tests for faster builds
        doCheck = false;
      };

      # Create the Docker image
      dockerImage = pkgs.dockerTools.buildImage {
        name = "meilisearch-local-nix";
        tag = version;

        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = with pkgs; [ tini curl meilisearch libgcc coreutils ];
          pathsToLink = [ "/bin" ];
        };

        extraCommands = ''
          mkdir -p meili_data tmp
          chmod 1777 tmp
          chmod 755 meili_data
        '';

        config = {
          Env = [
            "MEILI_HTTP_ADDR=0.0.0.0:7700"
            "MEILI_SERVER_PROVIDER=docker"
            "PATH=/bin:/usr/bin"
          ];

          WorkingDir = "/meili_data";

          ExposedPorts = { "7700/tcp" = { }; };

          Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
          Cmd = [ "${meilisearch}/bin/meilisearch" ];

          Labels = {
            "org.opencontainers.image.source" =
              "https://github.com/vncsmyrnk/meilisearch";
          };
        };
      };
    in {
      packages.${system} = {
        default = dockerImage;
        meilisearch = meilisearch;
        docker = dockerImage;
      };
    };
}

