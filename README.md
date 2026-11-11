# nix-herdr-app

A Nix flake that packages the prebuilt upstream [Herdr](https://herdr.dev) release builds.

Two packages:
- `herdr-app`: the [Herdr desktop app](https://github.com/herdrdev/herdr-app) (`herdr-app`). nixpkgs calls it `herdr-desktop`.
- `herdr-core`: the [Herdr core](https://github.com/herdrdev/herdr-core) (`herdr-core`, and `hc`).

nixpkgs builds both from source and lags upstream releases. This flake installs the release tarballs from `releases.herdr.dev`, which upstream's own installers use.

Both packages are pinned in `nix/pins.json` and kept current automatically: `.github/workflows/bump.yml` runs every 6 hours (and on `workflow_dispatch`). It reads upstream's `app/latest.json` and `core/latest.json` manifests, gates any change on a Linux `nix build` of both packages, and commits the pin update to `main`. No manual hash editing.

## Usage

Run the app directly:

```console
$ nix run github:cormacc/nix-herdr-app
```

Build either package:

```console
$ nix build '.#herdr-app' # packages.default
$ nix build '.#herdr-core'
$ result/bin/hc --version
```

### As a flake input

```nix
{
  inputs.nix-herdr-app.url = "github:cormacc/nix-herdr-app";

  outputs = { self, nixpkgs, nix-herdr-app }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ nix-herdr-app.overlays.default ];
          environment.systemPackages = [ pkgs.herdr-app pkgs.herdr-core ];
        })
      ];
    };
  };
}
```

`overlays.default` adds `herdr-app` and replaces nixpkgs' `herdr-core` with the release builds. It also sets nixpkgs' `herdr-desktop` to the same derivation as `herdr-app`, so a configuration or package that names `herdr-desktop` gets the release build. The overlay's `herdr-app` uses the overlay's `herdr-core`.

## Platforms

| Package         | `x86_64-linux` | `aarch64-linux` | `aarch64-darwin` | `x86_64-darwin` |
|-----------------|----------------|-----------------|------------------|-----------------|
| `herdr-app`     | yes            | yes             | yes              | no upstream build |
| `herdr-core`    | yes            | yes             | yes              | overlay only    |

nixpkgs-unstable has dropped `x86_64-darwin`, so the flake's `packages` do not include it. The overlay still provides `herdr-core` there when applied to a nixpkgs that supports it (26.05).

Only `x86_64-linux` is built and tested here. The macOS packages copy upstream's signed `Herdr.app` and `Herdr Core.app` bundles unchanged into `$out/Applications`.

## Differences from the nixpkgs packages

- The app finds the core: on Linux, a wrapper appends the `herdr-core` package to `PATH`, so a core earlier on `PATH` takes precedence. On macOS, install `herdr-core` into a profile; the app looks in `/run/current-system/sw/bin` and `~/.nix-profile/bin`.
- Updates: the app does not update itself, because the binary is not in a self-updating install layout. The core reports that Nix manages it, so the app does not offer core updates.
- Telemetry: upstream release builds send usage telemetry by default. Turn it off in Settings → Privacy. The nixpkgs source builds do not send it.
- `herdr-core` does not install the `herdr-core` agent skill. Run `hc --skill` for the agent manual.

## Licence

The files in this repository are released into the public domain under the [Unlicense](LICENSE). Herdr itself keeps its upstream licences; each package's `meta.license` and `share/licenses/` list them.

## LLM-use disclosure

This flake was largely written by an LLM -- because life's too short to write nix.
