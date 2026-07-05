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
        desktop_src = squash_root / "share/applications/com.mitchellh.ghostty.desktop"
        if desktop_src.exist?
          dst_dir = Pathname.new(File.expand_path("~/.local/share/applications"))
          dst_dir.mkpath
          content = desktop_src.read
                               .gsub(/^TryExec=.*$/, "TryExec=#{app_image_path}")
                               .gsub(/^Exec=.*$/,    "Exec=#{app_image_path}")
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

        # Add to PATH
        local_bin = Pathname.new(File.expand_path("~/.local/bin"))
        local_bin.mkpath
        ghostty_bin = local_bin / "ghostty"
        ghostty_bin.unlink if ghostty_bin.symlink?
        File.symlink(app_image_path, ghostty_bin)

        # Refresh XDG app grid
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

    uninstall_postflight do
      FileUtils.rm_f [
        File.expand_path("~/.local/bin/ghostty"),
        File.expand_path("~/.local/share/applications/com.mitchellh.ghostty.desktop"),
        File.expand_path("~/.local/share/terminfo/x/xterm-ghostty"),
      ]
      Dir.glob(File.expand_path("~/.local/share/icons/hicolor/*/apps/com.mitchellh.ghostty.png")).each do |icon|
        FileUtils.rm_f icon
      end
      update_cmd = %w[/usr/bin/update-desktop-database /usr/local/bin/update-desktop-database]
                   .find { |p| File.executable?(p) }
      system_command update_cmd, args: [File.expand_path("~/.local/share/applications")] if update_cmd
    end

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

      A `ghostty` symlink has been added to ~/.local/bin 

      Ghostty's terminfo entry has been installed to ~/.local/share/terminfo/.
      If remote hosts don't recognise xterm-ghostty, set TERM=xterm-256color before SSH.

      To also remove Ghostty config and cache on uninstall:
        brew uninstall --zap gooze/ghostty-appimage/ghostty-appimage
    EOS
  end
end
