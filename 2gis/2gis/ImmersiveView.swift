//
//  ImmersiveView.swift
//  2gis
//
//  Created by Павел on 04.10.2025.
//

import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel

    var body: some View {
        RealityView { content in
            // ---------- HEAD (стрелка) ----------
            let headAnchor = AnchorEntity(.head)
            headAnchor.name = "HeadAnchor"

            // Плоская плашка-стрелка, смотрит на пользователя (три экземпляра с шагом 1 м)
            let arrowSize: SIMD2<Float> = [0.40, 0.18]
            let mesh = MeshResource.generatePlane(width: arrowSize.x, height: arrowSize.y, cornerRadius: 0.03)

            func makeArrow(name: String, color: UIColor) -> ModelEntity {
                var mat = UnlitMaterial()
                mat.color = .init(tint: color)
                let e = ModelEntity(mesh: mesh, materials: [mat])
                e.name = name
                e.components.set(BillboardComponent())
                return e
            }

            let arrow1 = makeArrow(name: "ArrowBillboard1", color: .init(red: 0.0, green: 0.7, blue: 1.0, alpha: 1.0))
            let arrow2 = makeArrow(name: "ArrowBillboard2", color: .init(red: 0.1, green: 0.9, blue: 0.6, alpha: 1.0))
            let arrow3 = makeArrow(name: "ArrowBillboard3", color: .init(red: 1.0, green: 0.5, blue: 0.2, alpha: 1.0))

            let d0 = max(1.0 as Float, min(5.0 as Float, appModel.arrowDistance))
            arrow1.position = [0.0, 0.0, -d0]
            arrow2.position = [0.0, 0.0, -(d0 + 1.0)]
            arrow3.position = [0.0, 0.0, -(d0 + 2.0)]

            headAnchor.addChild(arrow1)
            headAnchor.addChild(arrow2)
            headAnchor.addChild(arrow3)
            headAnchor.isEnabled = (appModel.selectedScene == .arrow)
            content.add(headAnchor)

            // ---------- WORLD (куб) ----------
            let worldAnchor = AnchorEntity(world: SIMD3<Float>(0, 1.4, -1.5))
            worldAnchor.name = "WorldAnchorCube"

            let cube = ModelEntity(mesh: .generateBox(size: 0.45, cornerRadius: 0.06))
            cube.model?.materials = [
                SimpleMaterial(color: .init(red: 0.15, green: 0.55, blue: 0.95, alpha: 1.0),
                               roughness: 0.25, isMetallic: true)
            ]
            cube.transform.rotation = simd_quatf(angle: .pi / 6, axis: SIMD3<Float>(1, 1, 0))
            worldAnchor.addChild(cube)

            let key = DirectionalLight()
            key.light.color = .init(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
            key.light.intensity = 2_000
            key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 10, depthBias: 0.02)
            key.look(at: .zero, from: [1.5, 1.5, 1.0], relativeTo: worldAnchor)
            worldAnchor.addChild(key)

            let fill = DirectionalLight()
            fill.light.color = .init(white: 0.8, alpha: 1.0)
            fill.light.intensity = 600
            fill.look(at: .zero, from: [-1.0, 0.8, -0.5], relativeTo: worldAnchor)
            worldAnchor.addChild(fill)

            worldAnchor.isEnabled = (appModel.selectedScene == .cube)
            content.add(worldAnchor)

        } update: { content in
            // Обновляем дистанцию стрелок (всегда 1…5 м), с интервалом 1 м
            let d = max(1.0 as Float, min(5.0 as Float, appModel.arrowDistance))
            if let a1 = content.entities.first(where: { $0.name == "ArrowBillboard1" }) as? ModelEntity {
                a1.position = [0, 0, -d]
            }
            if let a2 = content.entities.first(where: { $0.name == "ArrowBillboard2" }) as? ModelEntity {
                a2.position = [0, 0, -(d + 1.0)]
            }
            if let a3 = content.entities.first(where: { $0.name == "ArrowBillboard3" }) as? ModelEntity {
                a3.position = [0, 0, -(d + 2.0)]
            }
            // Переключаем сцены без пересоздания
            if let headAnchor = content.entities.first(where: { $0.name == "HeadAnchor" }) {
                headAnchor.isEnabled = (appModel.selectedScene == .arrow)
            }
            if let worldAnchor = content.entities.first(where: { $0.name == "WorldAnchorCube" }) {
                worldAnchor.isEnabled = (appModel.selectedScene == .cube)
            }
        }
        .onAppear { appModel.immersiveSpaceState = .open }
        .onDisappear { appModel.immersiveSpaceState = .closed }
    }
}

