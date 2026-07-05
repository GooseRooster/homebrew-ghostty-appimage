cask "ghostty-appimage" do
  arch arm: "aarch64", intel: "x86_64"

  # Plain semver — no comma separator. Commas in the Caskroom directory path
  # break AppImage's FUSE mount (FUSE parses commas as option separators).
  # For re-releases tagged v1.2.0+1, version is "1.2.0+1"; the filename strips
  # the +N suffix via .split("+").first since asset names don't include it.
  version "1.3.1"
  sha256 :no_check

  url "https://github.com/pkgforge-dev/ghostty-appimage/releases/download/v#{version}/Ghostty-#{version.to_s.split("+").first}-#{arch}.AppImage",
      verified: "github.com/pkgforge-dev/ghostty-appimage/"
  name "Ghostty"
  desc "Fast, native, feature-rich terminal emulator (unofficial Linux AppImage build)"
  homepage "https://ghostty.org"

  livecheck do
    url "https://github.com/pkgforge-dev/ghostty-appimage"
    strategy :github_latest do |json, _regex|
      json["tag_name"]&.sub(/\Av/, "")  # "v1.3.1" → "1.3.1", "v1.2.0+1" → "1.2.0+1"
    end
  end

  on_linux do
    app_image "Ghostty-#{version.to_s.split("+").first}-#{arch}.AppImage", target: "Ghostty.AppImage"

    postflight do
      require "tmpdir"

      app_image_path = File.expand_path("~/Applications/Ghostty.AppImage")
      extract_dir    = Dir.mktmpdir("ghostty-appimage-")
      squash_root    = Pathname.new(extract_dir) / "squashfs-root"

      begin
        system_command app_image_path,
                       args:  ["--appimage-extract"],
                       chdir: extract_dir

        # .desktop — patch TryExec= and both Exec= lines (main section +
        # [Desktop Action new-window]) which embed the CI build path.
        # Strip DBusActivatable: GNOME tries D-Bus activation first when it's
        # set, and the AppImage ships no .service file, so the launch fails
        # silently without ever reaching Exec=.
        desktop_src = squash_root / "share/applications/com.mitchellh.ghostty.desktop"
        if desktop_src.exist?
          dst_dir = Pathname.new(File.expand_path("~/.local/share/applications"))
          dst_dir.mkpath
          content = desktop_src.read
                               .gsub(/^TryExec=.*$/, "TryExec=#{app_image_path}")
                               .gsub(/^Exec=.*$/,    "Exec=#{app_image_path} --gtk-single-instance=true")
                               .gsub(/^DBusActivatable=.*\n?/, "")
          (dst_dir / "com.mitchellh.ghostty.desktop").write(content)
        end

        # Icons — copy every size/HiDPI variant present (16x16, 16x16@2, 32x32,
        # 32x32@2, 128x128, 128x128@2, 256x256, 256x256@2, 512x512, 1024x1024)
        icon_src = squash_root / "share/icons/hicolor"
        icon_dst = Pathname.new(File.expand_path("~/.local/share/icons/hicolor"))
        if icon_src.exist?
          icon_src.each_child do |size_dir|
            next unless size_dir.directory?
            src_apps = size_dir / "apps"
            next unless src_apps.exist?
            dst_apps = icon_dst / size_dir.basename / "apps"
            dst_apps.mkpath
            src_apps.each_child { |f| FileUtils.cp(f, dst_apps / f.basename) }
          end
        end

        # terminfo — prevents "Error opening terminal: xterm-ghostty" in sudo / SSH
        terminfo_src = squash_root / "share/terminfo/x/xterm-ghostty"
        if terminfo_src.exist?
          terminfo_dst = Pathname.new(File.expand_path("~/.local/share/terminfo/x"))
          terminfo_dst.mkpath
          FileUtils.cp(terminfo_src, terminfo_dst / "xterm-ghostty")
        end

        # ~/.local/bin is in the GNOME session PATH on Fedora/Bluefin (via
        # systemd user environment), so a symlink here makes `ghostty` resolve
        # by name in GNOME keyboard shortcuts — same UX as a native install.
        local_bin = Pathname.new(File.expand_path("~/.local/bin"))
        local_bin.mkpath
        ghostty_bin = local_bin / "ghostty"
        ghostty_bin.unlink if ghostty_bin.symlink?
        File.symlink(app_image_path, ghostty_bin)

        # Refresh GNOME / XDG app grid
        update_cmd = %w[/usr/bin/update-desktop-database /usr/local/bin/update-desktop-database]
                     .find { |p| File.executable?(p) }
        if update_cmd
          system_command update_cmd,
                         args: [File.expand_path("~/.local/share/applications")]
        end
      ensure
        FileUtils.rm_rf(extract_dir)
      end
    end

    # Runs without sudo (uninstall script: defaults to sudo: false), so it can
    # cleanly remove user-owned XDG files on standard `brew uninstall`.
    uninstall script: {
      executable: "/bin/sh",
      args:       [
        "-c",
        'rm -f ' \
        '"$HOME/.local/bin/ghostty" ' \
        '"$HOME/.local/share/applications/com.mitchellh.ghostty.desktop" ' \
        '"$HOME/.local/share/terminfo/x/xterm-ghostty"; ' \
        'find "$HOME/.local/share/icons/hicolor" -name "com.mitchellh.ghostty.png" ' \
        '  -delete 2>/dev/null; ' \
        'command -v update-desktop-database >/dev/null 2>&1 && ' \
        '  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null; ' \
        'true',
      ],
    }

    # zap removes user config and cache (destructive — data loss; intentional)
    zap trash: [
      "~/.config/ghostty",
      "~/.cache/ghostty",
    ]
  end

  caveats do
    <<~EOS
      This is an UNOFFICIAL Linux AppImage build (pkgforge-dev/ghostty-appimage),
      not the official Ghostty distribution.

      A `ghostty` symlink has been added to ~/.local/bin/ for use in GNOME
      keyboard shortcuts and terminals that don't inherit Homebrew's PATH.

      Ghostty's terminfo entry has been installed to ~/.local/share/terminfo/.
      If remote hosts don't recognise xterm-ghostty, set TERM=xterm-256color before SSH.

      To also remove Ghostty config and cache on uninstall:
        brew uninstall --zap gooze/ghostty-appimage/ghostty-appimage
    EOS
  end
end
