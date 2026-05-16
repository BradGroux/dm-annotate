import SwiftUI

struct SettingsCommunitySectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup("Start Small, Think Big") {
                Text("SSTB.ai is the Digital Meld learning community for practical AI, automation, and implementation work.")
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    SettingsCommunityLink(
                        title: "SSTB.ai",
                        detail: "AI learning, automation, and transformation.",
                        systemImage: "globe",
                        url: URL(string: "https://www.sstb.ai/")!
                    )
                    SettingsCommunityLink(
                        title: "Podcast Playlist",
                        detail: "Start Small, Think Big on YouTube.",
                        systemImage: "play.rectangle",
                        url: URL(string: "https://www.youtube.com/playlist?list=PLw2ImU79nlNNgAbYOkdMpSPaqYgK2CDLR")!
                    )
                    SettingsCommunityLink(
                        title: "Discord Server",
                        detail: "Join the Start Small, Think Big community.",
                        systemImage: "bubble.left.and.bubble.right",
                        url: URL(string: "https://discord.gg/Gmfkm7QVSF")!
                    )
                }
            }
        }
    }
}
