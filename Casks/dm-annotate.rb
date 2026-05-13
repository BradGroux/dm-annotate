cask "dm-annotate" do
  version "0.1.9"
  sha256 "3d9139f5b70eac9efbd8ea893d368a71eb27631eb3b66228dd56bc9d5fc61bcd"

  url "https://github.com/BradGroux/dm-annotate/releases/download/v#{version}/dm-annotate-#{version}-macos.zip"
  name "Digital Meld Annotate"
  desc "Native, local-only screen annotation tool"
  homepage "https://github.com/BradGroux/dm-annotate"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "Digital Meld Annotate.app"

  zap trash: "~/Library/Preferences/io.digitalmeld.dm-annotate.plist"
end
