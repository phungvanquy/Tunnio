cask "tunnio" do
  version "VERSION"

  on_macos do
    arch arm: "arm64", intel: "amd64"

    sha256 arm:   "ARM_SHA256",
           intel: "AMD_SHA256"

    url "https://github.com/phungvanquy/Tunnio/releases/download/v#{version}/Tunnio-#{version}-macos-#{arch}.dmg"
  end

  name "Tunnio"
  desc "Multi-platform proxy client based on ClashMeta"
  homepage "https://github.com/phungvanquy/Tunnio"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :macos

  app "Tunnio.app"

  postflight do
    system_command "xattr",
                   args: ["-rd", "com.apple.quarantine", "#{appdir}/Tunnio.app"]
  end

  uninstall quit: "com.follow.clash"

  zap trash: [
    "~/Library/Application Support/com.follow.clash",
    "~/Library/Caches/com.follow.clash",
    "~/Library/Preferences/com.follow.clash.plist",
    "~/Library/Saved Application State/com.follow.clash.savedState",
  ]
end
