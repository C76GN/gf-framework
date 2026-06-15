# GF Extensions

GF extensions are optional capability bundles built on the GF kernel and standard library. Bundled GF extensions are disabled by default; projects enable only the extensions they need through `gf/extensions/enabled`, `GF Workspace`, a preset, or project code.

Each bundled extension lives directly under this directory:

```text
addons/gf/extensions/<extension_name>/
```

Each extension should provide a `gf_extension.json` manifest. Extension-level runtime services should register through manifest `installer_paths`; project-specific runtime registration should stay in project-level installers, so ownership remains explicit and testable.

Bundled GF extensions are atomic: they may depend only on `gf.kernel` and `gf.standard`, and they must not declare or probe other bundled extensions through hard dependencies, optional dependencies, paths, IDs, dynamic loading, or extension class names. Cross-extension composition belongs in project installers or standalone Godot plugins outside `addons/gf`.

For bundled GF extensions, manifest `version` must match the current GF release version, while `extension_version` tracks that individual extension's public behavior. Only extensions whose own API, configuration, behavior, or compatibility contract changed should bump `extension_version`.

Extension roots should only contain metadata, optional installer entry points, and extension docs. Runtime code belongs in stable slots such as `runtime`, `resources`, `nodes`, `editor`, `foundation`, or extension-specific domains.

The GF editor plugin opens the standalone `GF Workspace` with a `GF Extensions` page. It writes `gf/extensions/enabled`, can auto-run enabled extension installers before project installers, can exclude disabled extensions during export when `gf/extensions/export_exclude_disabled` is enabled, and can report disabled-extension references as export errors with `gf/extensions/export_fail_on_disabled_references`.
