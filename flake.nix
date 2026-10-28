{
  description = "Cached llama.cpp variants from stable and unstable nixpkgs and upstream master";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    llama-cpp.url = "github:ggml-org/llama.cpp/master";
  };

  outputs =
    { nixpkgs-unstable, nixpkgs-stable, llama-cpp, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs-unstable.lib;
      channels = {
        unstable = nixpkgs-unstable;
        stable = nixpkgs-stable;
      };
      variants = [
        "cpu"
        "cuda"
        "rocm"
        "vulkan"
      ];
      packages = nixpkgsPackages // masterPackages;
      masterPackages = lib.genAttrs (map (variant: "master-${variant}") variants) (
        name:
        let
          variant = lib.removePrefix "master-" name;
        in
        llama-cpp.packages.${system}.${if variant == "cpu" then "default" else variant}
      );
      nixpkgsPackages = lib.concatMapAttrs (
        channel: source:
        let
          pkgs = import source {
            inherit system;
            # CUDA dependencies have unfree redistribution licences.
            config.allowUnfree = true;
          };
        in
        lib.genAttrs (map (variant: "${channel}-${variant}") variants) (
          name:
          let
            variant = lib.removePrefix "${channel}-" name;
          in
          pkgs.llama-cpp.override {
            cudaSupport = variant == "cuda";
            rocmSupport = variant == "rocm";
            vulkanSupport = variant == "vulkan";
            metalSupport = false;
            openclSupport = false;
            inherit (pkgs) cudaPackages rocmPackages;
          }
        )
      ) channels;
    in
    {
      packages.${system} = packages // {
        default = packages.unstable-cpu;
      };

      overlays.default = final: prev: {
        # Keep the pinned inputs so these packages match the cache.
        llama-cpp-bin =
          assert prev.stdenv.hostPlatform.system == system;
          packages;
      };

      # Derivation checks evaluate every variant without requiring a GPU.
      checks.${system} = packages;
    };
}
