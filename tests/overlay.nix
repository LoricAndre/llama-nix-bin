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
assert builtins.attrNames overlay == [ "llama-cpp-bin" ];
assert builtins.attrNames overlay.llama-cpp-bin == builtins.attrNames packages;
assert builtins.all (name: overlay.llama-cpp-bin.${name}.drvPath == packages.${name}.drvPath) (
  builtins.attrNames packages
);
assert !(builtins.tryEval (applyOverlay "aarch64-linux").llama-cpp-bin).success;
true
