import SwiftUI

struct ScopeDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onTargeted: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
        onTargeted()
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        isTargeted = true
        onTargeted()
        return DropProposal(operation: .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        return onDrop(info.itemProviders(for: DropImporter.acceptedTypes))
    }
}

struct CountChip: View {
    let count: Int
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
            Text("\(count) \(label)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.07), in: Capsule())
    }
}

struct GlassTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.56 : 0.78))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.white.opacity(configuration.isPressed ? 0.08 : 0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}
