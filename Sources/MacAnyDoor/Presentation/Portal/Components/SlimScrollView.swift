import SwiftUI

struct SlimScrollView<Content: View>: View {
    private let content: Content
    @State private var viewportHeight: CGFloat = 1
    @State private var contentHeight: CGFloat = 1
    @State private var contentOffset: CGFloat = 0
    @State private var isHovering = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { viewport in
            ZStack(alignment: .topLeading) {
                ScrollView(.vertical) {
                    content
                        .padding(.trailing, 8)
                        .background(
                            GeometryReader { contentProxy in
                                Color.clear.preference(
                                    key: SlimContentHeightKey.self,
                                    value: contentProxy.size.height
                                )
                            }
                        )
                        .background(
                            GeometryReader { offsetProxy in
                                Color.clear.preference(
                                    key: SlimContentOffsetKey.self,
                                    value: offsetProxy.frame(in: .named("mac-any-door-scroll")).minY
                                )
                            }
                        )
                }
                .coordinateSpace(name: "mac-any-door-scroll")
                .scrollIndicators(.hidden)
                .onPreferenceChange(SlimContentHeightKey.self) { contentHeight = max($0, 1) }
                .onPreferenceChange(SlimContentOffsetKey.self) { contentOffset = max(-$0, 0) }

                if contentHeight > viewportHeight + 1 {
                    scrollIndicator(viewportHeight: viewport.size.height)
                }
            }
            .onAppear { viewportHeight = viewport.size.height }
            .onChange(of: viewport.size.height) { _, newHeight in viewportHeight = newHeight }
            .onHover { isHovering = $0 }
        }
    }

    private func scrollIndicator(viewportHeight: CGFloat) -> some View {
        let trackHeight = max(viewportHeight - 16, 1)
        let ratio = min(max(viewportHeight / max(contentHeight, 1), 0.12), 1)
        let knobHeight = max(28, trackHeight * ratio)
        let maxOffset = max(contentHeight - viewportHeight, 1)
        let maxTravel = max(trackHeight - knobHeight, 0)
        let knobOffset = min(max(contentOffset / maxOffset * maxTravel, 0), maxTravel)

        return ZStack(alignment: .top) {
            Capsule()
                .fill(.white.opacity(isHovering ? 0.13 : 0.07))
                .frame(width: 4, height: trackHeight)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(isHovering ? 0.62 : 0.42),
                            .white.opacity(isHovering ? 0.42 : 0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: isHovering ? 5 : 4, height: knobHeight)
                .offset(y: knobOffset)
        }
        .padding(.vertical, 8)
        .padding(.trailing, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }
}

private struct SlimContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 1

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SlimContentOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
