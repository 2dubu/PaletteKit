import PaletteKit
import SwiftUI

struct AsyncLoadView: View {
    @State private var urlString: String = "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800"
    @State private var useCache: Bool = true
    @State private var lastError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("AsyncPaletteGraphic")
                        .font(.title2.weight(.semibold))

                    TextField("Image URL", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Toggle("Use shared cache", isOn: $useCache)

                    if let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
                        AsyncPaletteGraphic(
                            image: .url(url),
                            cache: useCache ? .shared : nil,
                            onFailure: { lastError = String(describing: $0) }
                        ) {
                            ZStack {
                                Color.gray.opacity(0.1)
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .asyncPaletteGraphicTransition(.normal)
                    } else {
                        Text("Enter an http(s) URL").foregroundStyle(.secondary)
                    }

                    if let lastError {
                        Text("Last error: \(lastError)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("Clear shared cache", role: .destructive) {
                        PaletteCache.shared.clear()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Async load")
        }
    }
}

#Preview {
    AsyncLoadView()
}
