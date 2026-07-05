# homebrew-ghostty-appimage

A personal Homebrew tap providing `ghostty-appimage`, a Linux cask for the
unofficial [Ghostty AppImage](https://github.com/pkgforge-dev/ghostty-appimage)
built by pkgforge-dev.

> **This is a testing ground** for an eventual PR against the official
> [`Homebrew/homebrew-cask`](https://github.com/Homebrew/homebrew-cask)
> `ghostty` cask, adding Linux AppImage support via an `on_linux do` block.

---

## Install

```sh
brew tap gooserooster/ghostty-appimage
brew install --cask ghostty-appimage
```

## What gets installed

| Artifact | Location |
|---|---|
| AppImage | `~/Applications/Ghostty.AppImage` (symlink managed by Homebrew) |
| Desktop entry | `~/.local/share/applications/com.mitchellh.ghostty.desktop` |
| Icons | `~/.local/share/icons/hicolor/{size}/apps/com.mitchellh.ghostty.png` |
| Terminfo | `~/.local/share/terminfo/x/xterm-ghostty` |
| PATH symlink | `~/.local/bin/ghostty` → `~/Applications/Ghostty.AppImage` |

The `~/.local/bin/ghostty` symlink lets you use `ghostty` by name in GNOME
keyboard shortcuts (Settings → Keyboard → Custom Shortcuts) and in terminals
whose PATH doesn't include Homebrew's bin directory.

## Uninstall

```sh
# Removes the AppImage, desktop entry, icons, terminfo, and PATH symlink
brew uninstall --cask ghostty-appimage

# Also removes ~/.config/ghostty and ~/.cache/ghostty (destructive)
brew uninstall --zap --cask ghostty-appimage
```

## Updates

```sh
brew upgrade --cask ghostty-appimage
```

Livecheck tracks the upstream GitHub releases feed and skips the `tip`
(nightly) and `glfw` pre-release tracks automatically.

---

## Design notes

These are recorded here for the upstream PR discussion.

### Why a separate cask token?

This tap uses `ghostty-appimage` rather than `ghostty` so it can coexist
with the official `homebrew-cask` `ghostty` cask (macOS `.dmg`). The upstream
PR intent is to merge the Linux side into the existing `ghostty.rb` as an
`on_linux do` block, following the pattern of the `cursor` and
`beekeeper-studio` casks.

### Why `postflight` for desktop integration?

Homebrew's `app_image` artifact (`appimage.rb`) only symlinks the AppImage
into `~/Applications/` and sets `+x` — it does not touch `.desktop` files,
icons, or terminfo. No existing official cask uses `postflight` for this
purpose, making this a novel approach worth raising explicitly in the upstream
review.

### Desktop entry patching

The upstream AppImage's `.desktop` file contains absolute CI build paths in
`Exec=` and `TryExec=`. The postflight patches these to the installed symlink
path. `DBusActivatable=true` is stripped because the AppImage ships no D-Bus
service file; leaving it causes GNOME to attempt (and silently fail) D-Bus
activation instead of using `Exec=`.

### Version string (no comma)

An earlier iteration used a two-part CSV version (`"1.3.1,v1.3.1"`) to
separate the filename semver from the download tag. This was dropped because
Homebrew places the version string in the Caskroom directory path, and commas
in that path break AppImage's FUSE mount — FUSE parses commas as option
separators. The current approach uses a plain semver version and handles the
`+N` re-release edge case (where tag `v1.2.0+1` maps to filename
`Ghostty-1.2.0-*.AppImage`) via `version.to_s.split("+").first` in the URL
interpolation.

### Uninstall without sudo

`uninstall delete:` in Homebrew always invokes `sudo`, which fails
non-interactively for user-owned XDG paths. `uninstall script:` defaults to
`sudo: false` and is used instead to remove the desktop entry, icons, terminfo,
and PATH symlink on standard `brew uninstall`. User config and cache are left
to `zap trash:`.
