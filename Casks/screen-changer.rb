cask "screen-changer" do
  version "0.1.0"
  sha256 "92326a160c9f9bcd59b46d3c9cd9efa0e1be3d1fe2a24760384037655d167051"

  url "https://github.com/bobjer/screen-changer/releases/download/v#{version}/ScreenChanger-#{version}.zip"
  name "ScreenChanger"
  desc "Menu bar app for switching mirrored MacBook and external display roles"
  homepage "https://github.com/bobjer/screen-changer"

  depends_on macos: ">= :ventura"

  app "ScreenChanger.app"

  # Remove Gatekeeper quarantine — app is ad-hoc signed (no Apple Developer ID)
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-r", "-d", "com.apple.quarantine", "#{appdir}/ScreenChanger.app"],
                   sudo: false
  end
end
