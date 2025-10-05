import SwiftUI

struct SignpostWindow: View {
    let node: ManeuverNode
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Основная пиктограмма/иконка узла
            Text(node.title).font(.title2).bold()
            
            // Динамическая подсказка направления для пользователя (обновляется из AppModel)
            if !appModel.userTurnHint.isEmpty {
                Text(appModel.userTurnHint)
                    .font(.headline)
            }
            
            // Статическое описание точки (например: "через N м")
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
