import SwiftUI

struct ArrowWindow: View {
    let index: Int

    var body: some View {
        ArrowView()
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .navigationTitle("Стрелка #\(index)")
            .toolbar {
                ToolbarItem(placement: .status) {
                    Text("Окно со стрелкой #\(index)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
    }
}
