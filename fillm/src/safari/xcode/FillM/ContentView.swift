import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("FIL(L)M")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Fix It, LLM")
                .font(.headline)
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical)

            VStack(alignment: .leading, spacing: 12) {
                Text("Getting Started")
                    .font(.headline)

                HStack(alignment: .top) {
                    Text("1.")
                        .fontWeight(.bold)
                    Text("Open Safari and go to Settings → Extensions")
                }

                HStack(alignment: .top) {
                    Text("2.")
                        .fontWeight(.bold)
                    Text("Enable the FIL(L)M extension")
                }

                HStack(alignment: .top) {
                    Text("3.")
                        .fontWeight(.bold)
                    Text("Press ⌘⇧F on any webpage to start capturing")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            Spacer()

            Button(action: openSafariExtensionPreferences) {
                Text("Open Safari Extension Settings")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(minWidth: 400, minHeight: 400)
    }

    func openSafariExtensionPreferences() {
        // Open Safari's extension preferences
        if let url = URL(string: "x-apple.systempreferences:com.apple.Safari-Extensions-Preferences") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    ContentView()
}
