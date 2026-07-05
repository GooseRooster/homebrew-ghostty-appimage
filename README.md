# homebrew-ghostty-appimage

An unofficial Homebrew tap providing `ghostty-appimage`, a Linux cask for the
unofficial [Ghostty AppImage](https://github.com/pkgforge-dev/ghostty-appimage)
built by pkgforge-dev.


---

## Install

```sh
brew tap gooserooster/ghostty-appimage
brew trust gooserooster/ghostty-appimage
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


### Why a separate cask token?

This tap uses `ghostty-appimage` rather than `ghostty` so it can coexist
with the official `homebrew-cask` `ghostty` cask (macOS `.dmg`). 

### Why `postflight` for desktop integration?

Homebrew's `app_image` artifact (`appimage.rb`) only symlinks the AppImage
into `~/Applications/` and sets `+x` — it does not touch `.desktop` files,
icons, or terminfo. 

### Desktop entry and DBus activation

The upstream AppImage's `.desktop` file contains absolute CI build paths in
`Exec=` and `TryExec=`. The postflight patches these to the installed symlink
path and leaves `DBusActivatable=true` intact.

The AppImage ships a D-Bus service file at
`share/dbus-1/services/com.mitchellh.ghostty.service`. The postflight patches
its `Exec=` line and strips `SystemdService=` (no matching systemd unit ships
in the AppImage; stripping avoids a failed systemd activation before the D-Bus
daemon falls back to `Exec=`). The patched file is installed to
`~/.local/share/dbus-1/services/` so that D-Bus activation works: GNOME can
send messages to an already-running Ghostty instance rather than always
spawning a new process.


