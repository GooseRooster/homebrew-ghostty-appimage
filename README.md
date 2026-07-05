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

A daily github action will update the version in this tap when a new release is out.

---



