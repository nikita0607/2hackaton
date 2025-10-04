import SwiftUI

struct ArrowView: View {
    @State private var pulse = false

    var body: some View {
        GeometryReader { geometry in
            let minSide = min(geometry.size.width, geometry.size.height)
            let inset = minSide * 0.1

            ZStack {
                LinearGradient(colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: minSide * 0.2, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, y: 16)

                ArrowShape()
                    .fill(LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color.cyan.opacity(0.5), radius: 16, y: 8)
                    .overlay {
                        ArrowShape()
                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    }
                    .padding(inset)
                    .scaleEffect(pulse ? 1.05 : 1.0, anchor: .center)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
            }
        }
        .onAppear { pulse = true }
    }
}

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let headHeight = height * 0.4
        // Former `shaftWidth` wasn't used; shape already defined by percentage coords.

        path.move(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: width, y: headHeight))
        path.addLine(to: CGPoint(x: width * 0.68, y: headHeight))
        path.addLine(to: CGPoint(x: width * 0.68, y: height))
        path.addLine(to: CGPoint(x: width * 0.32, y: height))
        path.addLine(to: CGPoint(x: width * 0.32, y: headHeight))
        path.addLine(to: CGPoint(x: 0, y: headHeight))
        path.closeSubpath()

        return path
    }
}

#Preview {
    ArrowView()
        .frame(width: 260, height: 260)
        .padding()
        .background(Color.black.opacity(0.4))
}
