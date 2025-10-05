//
//  ImmersiveView.swift
//  2gis
//
//  Created by Павел on 04.10.2025.
//

import SwiftUI
import RealityKit
import UIKit // для UIColor

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
                e.components.set(BillboardComponent()) // всегда к камере :contentReference[oaicite:1]{index=1}
                return e
            }

            let arrow1 = makeArrow(name: "ArrowBillboard1", color: UIColor(red: 0.0, green: 0.7, blue: 1.0, alpha: 1.0))
            let arrow2 = makeArrow(name: "ArrowBillboard2", color: UIColor(red: 0.1, green: 0.9, blue: 0.6, alpha: 1.0))
            let arrow3 = makeArrow(name: "ArrowBillboard3", color: UIColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 1.0))

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
                SimpleMaterial(color: UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 1.0),
                               roughness: 0.25, isMetallic: true)
            ]
            cube.transform.rotation = simd_quatf(angle: .pi / 6, axis: SIMD3<Float>(1, 1, 0))
            worldAnchor.addChild(cube)

            let key = DirectionalLight()
            key.light.color = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
            key.light.intensity = 2_000
            key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 10, depthBias: 0.02)
            key.look(at: .zero, from: [1.5, 1.5, 1.0], relativeTo: worldAnchor)
            worldAnchor.addChild(key)

            let fill = DirectionalLight()
            fill.light.color = UIColor(white: 0.8, alpha: 1.0)
            fill.light.intensity = 600
            fill.look(at: .zero, from: [-1.0, 0.8, -0.5], relativeTo: worldAnchor)
            worldAnchor.addChild(fill)

            worldAnchor.isEnabled = (appModel.selectedScene == .cube)
            content.add(worldAnchor)

            // ---------- ROUTE OVERLAY (узлы манёвров) ----------
            let routeAnchor = AnchorEntity(.head) // держим в поле зрения и на комфортной дистанции
            routeAnchor.name = "RouteAnchor"
            content.add(routeAnchor)

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

            // [ROUTE OVERLAY] — гварды
            guard let origin = appModel.routeOriginLonLat, !appModel.maneuverNodes.isEmpty else {
                if let a = content.entities.first(where: { $0.name == "RouteAnchor" }) {
                    a.children.forEach { $0.removeFromParent() }
                }
                return
            }

            guard let routeAnchor = content.entities.first(where: { $0.name == "RouteAnchor" }) as? AnchorEntity else {
                return
            }

            // 1) Выбираем ближайший "следующий" манёвр — упрощённо: первый узел
            let next = appModel.maneuverNodes.first!

            // 2) Позиция таблички
            let nextPos = Geo.geoToMeters(
                lon: next.lon, lat: next.lat,
                originLon: origin.lon, originLat: origin.lat
            )
            let signY: Float = 1.4
            let signName = "RouteSignpost"

            // 2.1) Найти/создать табличку
            let sign: Entity
            if let existing = routeAnchor.children.first(where: { $0.name == signName }) {
                sign = existing
            } else {
                let e = makeSignpost(title: next.title, detail: next.detail)
                e.name = signName
                routeAnchor.addChild(e)
                sign = e
            }

            // 2.2) Обновить текст: пересоздадим текстовый mesh
            sign.children.forEach { child in
                if child is ModelEntity { child.removeFromParent() }
            }
            let wanted = [next.title, next.detail].compactMap { $0 }.joined(separator: "\n")
            if let textEntity = makeTextEntity(wanted) {
                textEntity.position = [0, 0, 0.001]
                sign.addChild(textEntity)
            }

            // 2.3) Позиция/настройки таблички
            //sign.position = [nextPos.x, signY, nextPos.z]
            if sign.components[BillboardComponent.self] == nil {
                sign.components.set(BillboardComponent()) // всегда к камере :contentReference[oaicite:2]{index=2}
            }

            // 3) Отрисовать 2–3 ближайших сегмента между узлами (тонкие плоскости)
            let maxSegments = 3
            let segRootName = "RouteSegmentsRoot"
            let segRoot: Entity = {
                if let ex = routeAnchor.children.first(where: { $0.name == segRootName }) { return ex }
                let r = Entity()
                r.name = segRootName
                routeAnchor.addChild(r)
                return r
            }()

            // подчистим старые детки (перерисуем быстро)
            segRoot.children.forEach { $0.removeFromParent() }

            let nodes = appModel.maneuverNodes
            if nodes.count >= 2 {
                for i in 0..<(min(nodes.count - 1, maxSegments)) {
                    let a = nodes[i], b = nodes[i + 1]
                    let pa = Geo.geoToMeters(lon: a.lon, lat: a.lat, originLon: origin.lon, originLat: origin.lat)
                    let pb = Geo.geoToMeters(lon: b.lon, lat: b.lat, originLon: origin.lon, originLat: origin.lat)
                    //if let seg = makeThinSegment(from: pa, to: pb, width: 0.25) {
                    //    segRoot.addChild(seg)
                    //}
                }
            }
        }
        .onAppear { appModel.immersiveSpaceState = .open }
        .onDisappear { appModel.immersiveSpaceState = .closed }
    }
}

// MARK: - Route overlay helpers

/// Плоская табличка-билборд (без текста; текст добавляем отдельно)
private func makeSignpost(title: String, detail: String?) -> Entity {
    let panelMesh = MeshResource.generatePlane(width: Float(0.35), height: Float(0.16), cornerRadius: Float(0.02))
    var panelMat = UnlitMaterial()
    panelMat.color = .init(tint: UIColor(white: 1.0, alpha: 0.85)) // полупрозрачная белая панель :contentReference[oaicite:3]{index=3}
    let panel = ModelEntity(mesh: panelMesh, materials: [panelMat])
    panel.components.set(BillboardComponent()) // смотрит на камеру :contentReference[oaicite:4]{index=4}
    // первичное наполнение (если есть)
    let textStr = [title, detail].compactMap { $0 }.joined(separator: "\n")
    if let textEntity = makeTextEntity(textStr) {
        textEntity.position = [0, 0, 0.001]
        panel.addChild(textEntity)
    }
    return panel
}

/// Текст как MeshResource → ModelEntity
private func makeTextEntity(_ string: String) -> ModelEntity? {
    // Шрифт RealityKit для text mesh
    let font = MeshResource.Font.systemFont(ofSize: 0.06, weight: .semibold) // :contentReference[oaicite:5]{index=5}
    let textMesh = MeshResource.generateText(
        string,
        extrusionDepth: 0.001,     // очень тонкий объём
        font: font                 // системный полужирный
        // остальные параметры опциональны
    ) // :contentReference[oaicite:6]{index=6}
    var textMat = UnlitMaterial()
    textMat.color = .init(tint: UIColor.black)
    return ModelEntity(mesh: textMesh, materials: [textMat])
}

/// Узкий сегмент между двумя узлами (в плоскости XZ)
private func makeThinSegment(from a: SIMD3<Float>, to b: SIMD3<Float>, width: Float) -> Entity? {
    let dx = b.x - a.x
    let dz = b.z - a.z
    let len = sqrt(dx * dx + dz * dz)
    guard len > 0.05 else { return nil }
    let mid = SIMD3<Float>((a.x + b.x) / 2, 0.01, (a.z + b.z) / 2)
    let planeMesh = MeshResource.generatePlane(width: len, height: width) // параметры типа Float :contentReference[oaicite:7]{index=7}
    var segMat = UnlitMaterial()
    segMat.color = .init(tint: UIColor(white: 1.0, alpha: 0.65))
    let plane = ModelEntity(mesh: planeMesh, materials: [segMat])
    // Повернём плоскость в XZ (yaw), чтобы длинная сторона совпала с направлением сегмента
    let yaw = atan2(dx, -dz)
    plane.transform.rotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
    plane.position = mid
    return plane
}
