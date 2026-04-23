cask "screen-changer" do
  version "0.1.0"
  sha256 "7b9cbbb665a3d48991465fcffedb6da1f70ed6d01440d3320e969a3b2c4bdb85"

  url "https://github.com/bobjer/screen-changer/releases/download/v#{version}/ScreenChanger-#{version}.zip"
  name "ScreenChanger"
  desc "Menu bar app for switching mirrored MacBook and external display roles"
  homepage "https://github.com/bobjer/screen-changer"

  depends_on arch: :arm64
  depends_on macos: ">= :tahoe"

  app "ScreenChanger.app"

  # Remove Gatekeeper quarantine — app is ad-hoc signed (no Apple Developer ID)
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-r", "-d", "com.apple.quarantine", "#{appdir}/ScreenChanger.app"],
                   sudo: false
  end
end
