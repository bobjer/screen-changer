cask "screen-changer" do
  version "0.1.0"
  sha256 "91cf718ad5f81984f1f7430620145087822b8e38df90063add4701e38ffbe7e8"

  url "https://github.com/bobjer/screen-changer/releases/download/v#{version}/ScreenChanger-#{version}.zip"
  name "ScreenChanger"
  desc "Menu bar app for switching mirrored MacBook and external display roles"
  homepage "https://github.com/bobjer/screen-changer"

  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "ScreenChanger.app"

  # Remove Gatekeeper quarantine — app is ad-hoc signed (no Apple Developer ID)
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-r", "-d", "com.apple.quarantine", "#{appdir}/ScreenChanger.app"],
                   sudo: false
  end
end
