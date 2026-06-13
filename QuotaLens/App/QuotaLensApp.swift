import SwiftUI

@main
struct QuotaLensApp: App {
    var body: some Scene {
        WindowGroup {
            MainShellView()
                .tint(QLTheme.brandPrimary)
        }
    }
}
