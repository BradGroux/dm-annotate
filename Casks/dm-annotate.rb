cask "dm-annotate" do
  version "0.1.8"
  sha256 "9b7056d1e3a7cc590470104fc79c218b6eab23bbe6a0c2428ece08528eb3d7e1"

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
