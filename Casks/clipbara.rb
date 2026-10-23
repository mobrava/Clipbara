cask "clipbara" do
  version "1.5.1"
  sha256 "01ef08ec5d4198ec0496983d0f1ba7dacfa57fa44cc9efc8680556d4dfa951c5"

  url "https://github.com/mobrava/Clipbara/releases/download/v#{version}/Clipbara-v#{version}.dmg"
  name "Clipbara"
  desc "Free, open-source clipboard manager for macOS (formerly PasteClip)"
  homepage "https://github.com/mobrava/Clipbara"

  depends_on macos: :sonoma

  app "Clipbara.app"

  zap trash: [
    "~/Library/Application Support/com.minsang.PasteClip",
    "~/Library/Preferences/com.minsang.PasteClip.plist",
  ]
end
