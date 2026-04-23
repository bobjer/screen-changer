cask "screen-changer" do
  version "0.1.0"
  sha256 "05bced91c94f61fc794384aded45612bc1a3d9799955dd6cb5ffd92b6b90e723"

  url "https://github.com/bobjer/screen-changer/releases/download/v#{version}/ScreenChanger-#{version}.zip"
  name "ScreenChanger"
  desc "Menu bar app for switching mirrored MacBook and external display roles"
  homepage "https://github.com/bobjer/screen-changer"

  depends_on macos: ">= :ventura"

  app "ScreenChanger.app"
end
