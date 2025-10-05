import SwiftUI

struct ArrowView: View {
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let size  = min(geo.size.width, geo.size.height)
            let inset = size * 0.1

            ArrowShape()
                .fill(LinearGradient(colors: [Color.cyan, Color.blue],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.cyan.opacity(0.5), radius: 16, y: 8)
                .overlay {
                    ArrowShape()
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                }
                .scaleEffect(pulse ? 1.05 : 1.0, anchor: .center)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                .frame(width: size - inset * 2, height: size - inset * 2)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .onAppear { pulse = true }
    }
}

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let headH = h * 0.4

        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w,       y: headH))
        path.addLine(to: CGPoint(x: w * 0.68,y: headH))
        path.addLine(to: CGPoint(x: w * 0.68,y: h))
        path.addLine(to: CGPoint(x: w * 0.32,y: h))
        path.addLine(to: CGPoint(x: w * 0.32,y: headH))
        path.addLine(to: CGPoint(x: 0,       y: headH))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ArrowView()
        .frame(width: 640, height: 260)
        .background(Color.clear)
        .padding()
}
