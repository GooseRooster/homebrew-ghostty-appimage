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


## Known limitation: terminfo under `sudo`

Running a `sudo`'d command (e.g. `sudo systemctl status ...`) from a Ghostty
terminal can print:

```
'xterm-ghostty': unknown terminal type.
```

The terminfo entry above installs to `~/.local/share/terminfo` (user-scoped
ncurses search path) — correct for a normal shell, but on distros whose
`sudoers` sets `Defaults always_set_home` (Fedora/RHEL-family, including
Fedora Atomic/Bluefin), `sudo` unconditionally resets `$HOME` to root's home,
so ncurses under `sudo` can't find it and falls back to the compiled-in
terminal database, which doesn't include `xterm-ghostty`.

Workaround: mirror the compiled entry into `/etc/terminfo`, which is in
ncurses' default search path regardless of `$HOME`:

```sh
sudo mkdir -p /etc/terminfo/x
sudo cp ~/.local/share/terminfo/x/xterm-ghostty /etc/terminfo/x/xterm-ghostty
```

Or work around it per-invocation: `sudo env TERM=xterm-256color <command>`.

This isn't something the cask itself can fix (it only has access to the
invoking user's `$HOME`, not root's) 

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



