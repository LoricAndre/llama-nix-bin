flake:
let
  applyOverlay =
    system:
    flake.overlays.default { } {
      stdenv.hostPlatform.system = system;
    };
  overlay = applyOverlay "x86_64-linux";
  packages = builtins.removeAttrs flake.packages.x86_64-linux [ "default" ];
in
assert builtins.attrNames packages == [
  "master-cpu"
  "master-cuda"
  "master-rocm"
  "master-vulkan"
  "stable-cpu"
  "stable-cuda"
  "stable-rocm"
  "stable-vulkan"
  "unstable-cpu"
  "unstable-cuda"
  "unstable-rocm"
  "unstable-vulkan"
];
assert builtins.all (
  variant:
  let
    upstreamName = if variant == "cpu" then "default" else variant;
  in
  packages.${"master-${variant}"}.drvPath
  == flake.inputs.llama-cpp.packages.x86_64-linux.${upstreamName}.drvPath
) [ "cpu" "cuda" "rocm" "vulkan" ];
assert flake.packages.x86_64-linux.default.drvPath == packages.unstable-cpu.drvPath;
assert builtins.attrNames overlay == [ "llama-cpp-bin" ];
assert builtins.attrNames overlay.llama-cpp-bin == builtins.attrNames packages;
assert builtins.all (name: overlay.llama-cpp-bin.${name}.drvPath == packages.${name}.drvPath) (
  builtins.attrNames packages
);
assert !(builtins.tryEval (applyOverlay "aarch64-linux").llama-cpp-bin).success;
true
