cask "ghostty-appimage" do
  arch arm: "aarch64", intel: "x86_64"

  # version.csv.first  = bare semver for filename  ("1.3.1")
  # version.csv.second = full tag for download path ("v1.3.1" or "v1.2.0+1" on re-releases)
  version "1.3.1,v1.3.1"
  sha256 :no_check

  url "https://github.com/pkgforge-dev/ghostty-appimage/releases/download/#{version.csv.second}/Ghostty-#{version.csv.first}-#{arch}.AppImage",
      verified: "github.com/pkgforge-dev/ghostty-appimage/"
  name "Ghostty"
  desc "Fast, native, feature-rich terminal emulator (unofficial Linux AppImage build)"
  homepage "https://ghostty.org"

  livecheck do
    url "https://github.com/pkgforge-dev/ghostty-appimage"
    strategy :github_latest do |json, _regex|
      tag = json["tag_name"]                         # "v1.3.1" or "v1.2.0+1"
      ver = tag.sub(/\Av/, "").sub(/\+\d+\z/, "")    # "1.3.1"  or "1.2.0"
      "#{ver},#{tag}"                                # "1.3.1,v1.3.1" or "1.2.0,v1.2.0+1"
    end
  end

  on_linux do
    app_image "Ghostty-#{version.csv.first}-#{arch}.AppImage", target: "Ghostty.AppImage"

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
        # [Desktop Action new-window]) which contain the CI build path
        desktop_src = squash_root / "share/applications/com.mitchellh.ghostty.desktop"
        if desktop_src.exist?
          dst_dir = Pathname.new(File.expand_path("~/.local/share/applications"))
          dst_dir.mkpath
          content = desktop_src.read
                               .gsub(/^TryExec=.*$/, "TryExec=#{app_image_path}")
                               .gsub(/^Exec=.*$/,    "Exec=#{app_image_path} --gtk-single-instance=true")
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

    # Postflight-written files are not tracked by Homebrew; list them explicitly
    # so `brew uninstall` removes them. Paths that don't exist are skipped harmlessly.
    uninstall delete: [
      "#{Dir.home}/.local/share/applications/com.mitchellh.ghostty.desktop",
      "#{Dir.home}/.local/share/terminfo/x/xterm-ghostty",
      "#{Dir.home}/.local/share/icons/hicolor/16x16/apps/com.mitchellh.ghostty.png",
      "#{Dir.home}/.local/share/icons/hicolor/16x16@2/apps/com.mitchellh.ghostty.png",
      "#{Dir.home}/.local/share/icons/hicolor/32x32/apps/com.mitchellh.ghostty.png",
      "#{Dir.home}/.local/share/icons/hicolor/32x32@2/apps/com.mitchellh.ghostty.png",
      "#{Dir.home}/.local/share/icons/hicolor/128x128/apps/com.mitchellh.ghostty.png",
      "#{Dir.home}/.local/share/icons/hicolor/128x128@2/apps/com.mitchellh.ghostty.png",
      "#{Dir.home}/.local/share/icons/hicolor/256x256/apps/com.mitchellh.ghostty.png",
      "#{Dir.home}/.local/share/icons/hicolor/256x256@2/apps/com.mitchellh.ghostty.png",
      "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/com.mitchellh.ghostty.png",
      "#{Dir.home}/.local/share/icons/hicolor/1024x1024/apps/com.mitchellh.ghostty.png",
    ]

    zap trash: [
      "~/.config/ghostty",
      "~/.cache/ghostty",
    ]
  end

  caveats do
    <<~EOS
      This is an UNOFFICIAL Linux AppImage build (pkgforge-dev/ghostty-appimage),
      not the official Ghostty distribution.

      Ghostty's terminfo entry has been installed to ~/.local/share/terminfo/.
      If remote hosts don't recognise xterm-ghostty, set TERM=xterm-256color before SSH.
    EOS
  end
end
