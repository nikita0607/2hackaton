import SwiftUI

struct ArrowWindow: View {
    var body: some View {
        ArrowView()
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .navigationTitle("Стрелка")
            .toolbar {
                // опционально — небольшая подсказка
                ToolbarItem(placement: .status) {
                    Text("Окно со стрелкой").font(.footnote).foregroundStyle(.secondary)
                }
            }
    }
}
