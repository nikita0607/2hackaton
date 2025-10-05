import SwiftUI

struct SignpostWindow: View {
    let node: ManeuverNode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(node.title).font(.title2).bold()
            if let d = node.detail { Text(d).font(.footnote) }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .navigationTitle("Навигация")
        .toolbar {
            ToolbarItem(placement: .status) {
                Text("Точка маршрута").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }
}
