# llama-nix-bin

Nightly Nix builds of `llama-cpp` for **x86_64-linux**, with a public Cachix binary cache.

| nixpkgs source | CPU | NVIDIA CUDA | AMD ROCm | Vulkan |
| --- | --- | --- | --- | --- |
| `nixpkgs-unstable` | `unstable-cpu` | `unstable-cuda` | `unstable-rocm` | `unstable-vulkan` |
| Latest stable NixOS release | `stable-cpu` | `stable-cuda` | `stable-rocm` | `stable-vulkan` |

The default package is `unstable-cpu`. The CPU variant keeps the nixpkgs BLAS default. GPU variants use the GPU targets selected by their nixpkgs revision. No GPU is needed to compile them.

## One-time setup

1. Make this repository public. Standard GitHub-hosted runners are free for public repositories.
2. Create a **public** cache at [Cachix](https://app.cachix.org/).
3. In GitHub **Settings → Secrets and variables → Actions**, add:
   - Repository variable `CACHIX_CACHE`: your cache name.
   - Repository secret `CACHIX_AUTH_TOKEN`: a Cachix token with permission to write to that cache.
4. Permit GitHub Actions to write repository contents. Branch rules must permit the bot to update `flake.nix` and `flake.lock` directly on `main`.
5. Push these files to `main`, then run **Build and cache** from the Actions tab. Check each matrix job.

There is no cache account or token in this repository. The workflow cannot publish binaries until you complete these steps. Keep the repository variable set to the same cache that users configure below.

## Use the binaries

Install Nix with flakes enabled. Enable the cache once, with your actual cache name:

```sh
nix run nixpkgs#cachix -- use YOUR_CACHE_NAME
```

This command configures the cache URL and its public signing key. A multi-user Nix installation can require administrator access. For NixOS, copy those values into `nix.settings.substituters` and `nix.settings.trusted-public-keys` in your system configuration, then rebuild.

Build and start a server:

```sh
nix build github:LoricAndre/llama-nix-bin#unstable-cuda
./result/bin/llama-server --model /path/to/model.gguf
```

Or run the server in a temporary shell. This avoids reliance on the nixpkgs package's main-program metadata:

```sh
nix shell github:LoricAndre/llama-nix-bin#unstable-cuda --command llama-server --help
```

Use a package from this flake to match the cached store path. A local nixpkgs override with different inputs, GPU targets, or build flags can produce a different path and require a local build. Do not make these inputs follow another nixpkgs revision if you need an exact cache match.

For a NixOS flake:

```nix
{
  inputs.llama-nix-bin.url = "github:LoricAndre/llama-nix-bin";

  outputs = { nixpkgs, llama-nix-bin, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        { environment.systemPackages = [
            llama-nix-bin.packages.x86_64-linux.unstable-cuda
          ];
        }
      ];
    };
  };
}
```

Add this input to your existing flake; the example omits your other inputs. Configure the public cache on the host separately. Update the `llama-nix-bin` input lock when you want newer binaries. Pin this repository to a commit if you need a fixed version.

GPU drivers are not included in the cache setup. Enable the correct NVIDIA, ROCm, or Vulkan runtime on your host. GPU compatibility is determined by nixpkgs and your driver. CUDA dependencies are unfree; this flake permits them during evaluation. Check their licence terms before redistribution.

## Automatic updates and builds

At **03:23 UTC each day**, and on a manual run, the workflow:

1. Reads the stable release links on the [official NixOS download page](https://nixos.org/download). It stops with an error if that page no longer has the expected links.
2. Updates the stable branch in `flake.nix`, then runs `nix flake update` for both inputs.
3. Commits changed inputs on the default branch. It does not create a pull request or require a personal access token.
4. Passes the exact flake and lock file to eight independent build jobs. `fail-fast: false` keeps the other jobs running after a failure. Package evaluation is also done inside each build job.
5. Builds all package outputs, including development headers. The Cachix action uploads new store paths and their dependencies. Existing cached outputs are reused.

Pushes to `main` build the committed lock file without updating it. Pull requests run the Python tests and evaluate all variants; they do not run builds with cache secrets. Actions are pinned to commit hashes. Review and update these pins when required.

Versions, source hashes, patches, and dependency hashes come from nixpkgs. **Nightly means new nixpkgs revisions, not llama.cpp Git HEAD.** Stable can have an older llama.cpp version than unstable.

A failed backend does not stop successful backends from uploading. The overall workflow still reports a failure, so it remains visible. Input commits happen before the builds: a new repository revision does **not** guarantee that every binary is already in the cache. Use the Actions results to confirm availability. If an output is missing, Nix can build it locally. A failed variant is retried on the next nightly run, even when the lock file has not changed.

GitHub can delay scheduled jobs. It also disables schedules in public repositories after 60 days without repository activity. Normal input-update commits provide activity; check the Actions tab if updates stop for a long period.

## Free service limits

[Cachix's free open-source allowance](https://www.cachix.org/pricing) is currently **5 GB**. Paths already in `cache.nixos.org` do not normally use this allowance. Cachix removes least recently used entries at the storage limit. This is a rolling cache, not permanent release storage. Eight variants and their GPU dependencies can exceed the allowance, so old or even current variants can be removed. Ask Cachix about more open-source storage if this occurs.

Cachix is the initial choice because it provides a signed public Nix cache and a maintained GitHub Action without a storage service to manage. GitHub artifacts are not a Nix substituter. Attic requires a server and storage; object storage also needs hosting, credentials, and cache signing. Neither guarantees a better free allowance.

The workflow removes unused SDKs from each runner and limits Nix to one build job with two compilation cores. CUDA and ROCm can still exceed free runner disk, RAM, or the **six-hour job limit**, especially when a dependency is not in `cache.nixos.org`. This setup does not promise that every GPU build fits a free runner. If it fails for capacity reasons, use a larger or self-hosted runner for that matrix entry, or choose fewer GPU targets. Different target overrides also change cache paths.

## Local checks

```sh
python3 -m unittest discover -s tests -v
nix flake check --no-build --show-trace
nix build '.#unstable-cpu^*'
```

To update inputs locally, run `python3 scripts/update-inputs.py`. Review and commit the changes to both `flake.nix` and `flake.lock`.
