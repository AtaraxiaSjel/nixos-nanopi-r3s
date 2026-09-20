# Model registry for the R3S family: { r3s = {...}; r3s-lts = {...}; }.
# Consumed by flake.nix for board modules, loaders and images.
{
  r3s = import ./r3s.nix;
  r3s-lts = import ./r3s-lts.nix;
}
