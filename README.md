# llama-nix-bin

Prebuilt `llama-cpp` packages for **x86_64-linux**, updated nightly from `nixpkgs-unstable` and the latest stable NixOS release. Available backends: CPU, NVIDIA CUDA, AMD ROCm, and Vulkan.

## Enable the binary cache

Add the cache URL and public signing key to your Nix configuration. You do **not** need the Cachix CLI, an account, or this repository as a flake input.

The public cache is at **https://llama-nix-bin.cachix.org**. Its public signing key is included in the examples below.

For NixOS, add this to your system configuration, then run `sudo nixos-rebuild switch`:

```nix
{
  nix.settings = {
    extra-substituters = [ "https://llama-nix-bin.cachix.org" ];
    extra-trusted-public-keys = [ "llama-nix-bin.cachix.org-1:FbrkA2/RiLOndFgV+MUyS5Cd9vpB4Df0W0CGeZi2ewU=" ];
  };
}
```

On other systems, add this to `/etc/nix/nix.conf`:

```ini
extra-substituters = https://llama-nix-bin.cachix.org
extra-trusted-public-keys = llama-nix-bin.cachix.org-1:FbrkA2/RiLOndFgV+MUyS5Cd9vpB4Df0W0CGeZi2ewU=
```

Restart the Nix daemon after a change to its configuration. On Linux with systemd, use `sudo systemctl restart nix-daemon`. For a single-user installation, use `~/.config/nix/nix.conf`; no daemon restart is needed. A multi-user installation requires an administrator to configure the cache as trusted.

The `extra-` settings keep your existing caches and keys, including `cache.nixos.org`.

## Use your existing nixpkgs package

Keep your current package configuration. Nix will check the cache automatically when it builds `llama-cpp`. For example, in a NixOS module:

```nix
{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.llama-cpp.override {
      cudaSupport = true;
      rocmSupport = false;
      vulkanSupport = false;
      metalSupport = false;
      openclSupport = false;
      inherit (pkgs) cudaPackages;
    })
  ];
}
```

CUDA dependencies are unfree. Permit their licences in your nixpkgs configuration, for example with `nixpkgs.config.allowUnfree = true;` after you review their terms. CPU, ROCm, and Vulkan variants do not need CUDA support.

**A binary cache does not change your package version or build options.** A cache hit requires the same derivation: the nixpkgs revision, dependency versions, GPU targets, and build flags must match a cached build. A different nixpkgs revision can still match if those inputs did not change, but this is not guaranteed. If no matching binary is available, Nix builds the package locally.

The cache stores the standard nixpkgs GPU targets. Custom GPU targets or CPU tuning can require a local build. Enable the correct GPU drivers and runtime on your host; the cache does not configure them.

## Optional: use the pinned packages

Use this repository's packages when you want the exact inputs used by the nightly builds. You can use them directly, without adding a flake input:

```sh
nix build github:LoricAndre/llama-nix-bin#unstable-cuda
./result/bin/llama-server --model /path/to/model.gguf

# Or run a server in a temporary shell:
nix shell github:LoricAndre/llama-nix-bin#stable-vulkan --command llama-server --help
```

These commands require flakes to be enabled. Configure the cache separately as shown above.

| nixpkgs source | CPU | NVIDIA CUDA | AMD ROCm | Vulkan |
| --- | --- | --- | --- | --- |
| `nixpkgs-unstable` | `unstable-cpu` | `unstable-cuda` | `unstable-rocm` | `unstable-vulkan` |
| Latest stable NixOS release | `stable-cpu` | `stable-cuda` | `stable-rocm` | `stable-vulkan` |

The default package is `unstable-cpu`. The CPU variant keeps the nixpkgs BLAS default. Versions come from nixpkgs, not llama.cpp Git HEAD; stable can have an older version than unstable.

### Nixpkgs overlay

The default overlay adds `pkgs.llama-cpp-bin`, with the eight package names listed above. It does **not** replace `pkgs.llama-cpp`. Its packages keep this repository's pinned nixpkgs inputs, rather than rebuilding against your host's nixpkgs. The overlay supports `x86_64-linux` only.

Add this input to your existing flake:

```nix
inputs.llama-nix-bin.url = "github:LoricAndre/llama-nix-bin";
```

Include `llama-nix-bin` in your `outputs` arguments, then add this module to your `nixosSystem.modules` list:

```nix
({ pkgs, ... }: {
  nixpkgs.overlays = [ llama-nix-bin.overlays.default ];
  environment.systemPackages = [ pkgs.llama-cpp-bin.unstable-cuda ];
})
```

You can also select packages without the overlay:

```nix
environment.systemPackages = [
  llama-nix-bin.packages.x86_64-linux.unstable-cuda
];
```

Update your `llama-nix-bin` input lock to get newer packages. Do not make its nixpkgs inputs follow your own nixpkgs input if you want to keep the nightly build inputs. Pin this repository to a commit for a fixed version.

## Availability

Check [Actions](https://github.com/LoricAndre/llama-nix-bin/actions) for build results. A failed variant does not stop the other variants from uploading, but a new input commit does not guarantee that all binaries are ready.

The free cache has limited storage and can remove entries, including current variants. It is not permanent release storage. If an output is missing, Nix can build it locally.

## Development

### Initial publishing setup

1. Make this repository public to use free standard GitHub-hosted runners.
2. Open the existing [llama-nix-bin cache](https://app.cachix.org/cache/llama-nix-bin#push).
3. Set the GitHub Actions repository variable `CACHIX_CACHE` to `llama-nix-bin`.
4. Set the repository secret `CACHIX_AUTH_TOKEN` to a token with write access to that cache.
5. Keep the public cache URL and signing key in this README current. Never publish the authentication token or a private signing key.
6. Permit Actions to write repository contents. Branch rules must let the bot update `flake.nix` and `flake.lock` directly on `main`.
7. Push to `main`, or start **Build and cache** from the Actions tab. Check each matrix job.

### Nightly updates and CI

At **03:23 UTC each day**, and on a manual run, `.github/workflows/build.yml`:

1. Reads stable release links from the [official NixOS download page](https://nixos.org/download). Detection fails with an error if the expected links are missing.
2. Updates the stable branch in `flake.nix` and runs `nix flake update` for both nixpkgs inputs.
3. Commits changed inputs on the default branch with `GITHUB_TOKEN`. No personal access token is needed.
4. Passes the exact flake and lock file to eight independent matrix jobs. `fail-fast: false` keeps the other jobs running after a failure. Each job evaluates its own package.
5. Builds all outputs, including development headers. The Cachix action uploads new store paths and their dependencies; existing cached outputs are reused.

Build runners also use the [NixOS CUDA binary cache](https://cache.nixos-cuda.org), with its public signing key, to reuse available CUDA packages instead of compiling them. The standard NixOS cache and this project's Cachix cache remain enabled.

Source versions, hashes, patches, and dependency hashes stay under nixpkgs control. The overlay exports the same derivations as the package outputs.

Pushes to `main` build the committed inputs without updating them. Pull requests run the Python tests and evaluate all variants; they do not run cache-enabled builds. Actions are pinned to commit hashes; review and update those pins when needed.

Inputs are committed before builds start. A build failure leaves the input update in place and is reported by Actions. Failed variants are retried the next night even if the lock file does not change.

GitHub can delay scheduled runs. It disables schedules in public repositories after 60 days without repository activity. Input-update commits normally provide activity; check Actions if updates stop for a long period.

### Capacity and cache service

[Cachix's free open-source allowance](https://www.cachix.org/pricing) is currently **5 GB**. Paths already in `cache.nixos.org` do not normally use this allowance. Cachix removes least recently used entries at the storage limit. Eight variants and GPU dependencies can exceed it. Request more open-source storage if required.

Cachix provides a signed public Nix cache and a maintained GitHub Action without a server to manage. GitHub artifacts are not a Nix substituter. Attic needs a server and storage; object storage also needs hosting, credentials, and signing. Neither guarantees a better free allowance.

The workflow removes unused runner SDKs and limits Nix to one build job with two compilation cores. CUDA and ROCm can still exceed free runner disk, RAM, or the **six-hour job limit**, especially for dependencies missing from `cache.nixos.org`. Use a larger or self-hosted runner for affected matrix entries, or select fewer GPU targets. Target changes also change cache paths. Review CUDA redistribution licence terms before publishing its dependencies.

### Local checks

```sh
python3 -m unittest discover -s tests -v
nix eval --impure --expr 'import ./tests/overlay.nix (builtins.getFlake (toString ./.))'
nix flake check --no-build --show-trace
nix build '.#unstable-cpu^*'
```

To update inputs locally, run `python3 scripts/update-inputs.py`. Review and commit both `flake.nix` and `flake.lock`.
