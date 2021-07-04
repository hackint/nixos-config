sources:
[
  (self: super: {
    morph = self.callPackage sources.morph { };
  })

  (self: super: {
    nix-pre-commit-hooks = import sources.nix-pre-commit-hooks;
  })
]
