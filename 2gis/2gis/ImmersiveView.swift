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
            guard appModel.selectedScene == .cube else { return }

            let anchor = AnchorEntity(world: SIMD3<Float>(0, 1.4, -1.5))

            let cube = ModelEntity(mesh: .generateBox(size: 0.45, cornerRadius: 0.06))
            cube.model?.materials = [SimpleMaterial(color: .init(red: 0.15, green: 0.55, blue: 0.95, alpha: 1.0), roughness: 0.25, isMetallic: true)]
            cube.transform.rotation = simd_quatf(angle: .pi / 6, axis: SIMD3<Float>(1, 1, 0))
            anchor.addChild(cube)

            let light = DirectionalLight()
            light.light.color = .init(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
            light.light.intensity = 2_000
            light.shadow = DirectionalLightComponent.Shadow(maximumDistance: 10, depthBias: 0.02)
            light.look(at: .zero, from: [1.5, 1.5, 1.0], relativeTo: anchor)
            anchor.addChild(light)

            // Fill light instead of ambient (AmbientLightComponent not available on visionOS 2.3)
            let fill = DirectionalLight()
            fill.light.color = .init(white: 0.8, alpha: 1.0)
            fill.light.intensity = 600
            fill.look(at: .zero, from: [-1.0, 0.8, -0.5], relativeTo: anchor)
            anchor.addChild(fill)

            content.add(anchor)
        }
        .onAppear {
            appModel.immersiveSpaceState = .open
        }
        .onDisappear {
            appModel.immersiveSpaceState = .closed
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
