import SwiftUI
import UniformTypeIdentifiers

private enum PrimarySection: String, CaseIterable, Identifiable {
    case temporary
    case permanent

    var id: Self { self }

    var title: String {
        switch self {
        case .temporary:
            return "一次性"
        case .permanent:
            return "长期"
        }
    }

    var subtitle: String {
        switch self {
        case .temporary:
            return "默认保存 24 小时"
        case .permanent:
            return "长期保留"
        }
    }

    var symbolName: String {
        switch self {
        case .temporary:
            return "clock.arrow.circlepath"
        case .permanent:
            return "archivebox"
        }
    }
}

struct PortalRootView: View {
    @ObservedObject var store: PortalStore
    @ObservedObject var panelController: NotchPanelController
    let dropImporter: DropImporter

    @State private var primarySection: PrimarySection = .temporary
    @State private var isTemporaryDropTarget = false
    @State private var isPermanentDropTarget = false
    @State private var isTemporaryTabDropTarget = false
    @State private var isPermanentTabDropTarget = false
    @State private var isPromptDropTarget = false
    @State private var isOrderingPermanents = false
    @State private var isShowingNewMaterialSheet = false

    var body: some View {
        Group {
            if panelController.isExpanded {
                expandedBody
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                        )
                    )
            } else {
                collapsedBody
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }
        }
        .animation(
            .spring(response: 0.44, dampingFraction: 0.84, blendDuration: 0.08),
            value: panelController.isExpanded
        )
        .frame(
            width: panelController.isExpanded ? NotchPanelController.expandedSize.width : NotchPanelController.collapsedSize.width,
            height: panelController.isExpanded ? NotchPanelController.expandedSize.height : NotchPanelController.collapsedSize.height
        )
        .sheet(isPresented: $isShowingNewMaterialSheet) {
            NewMaterialSheet(store: store)
        }
    }

    private var collapsedBody: some View {
        Button {
            panelController.show()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.mint)

                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(width: 1, height: 14)

                Text("任意门")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                Text("\(store.temporaryItems.count + store.permanentItems.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.mint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Color.black.opacity(0.78), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.32), radius: 12, y: 5)
        .contentShape(Capsule())
        .accessibilityLabel("打开 Mac 任意门")
    }

    private var expandedBody: some View {
        VStack(spacing: 13) {
            header
            scopeSwitcher

            Group {
                if primarySection == .temporary {
                    temporaryContent
                } else {
                    permanentContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let notice = store.notice {
                NoticeBanner(notice: notice) {
                    store.dismissNotice()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(FrostedPanelBackground())
        .shadow(color: .black.opacity(0.38), radius: 24, y: 10)
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.mint.opacity(0.16))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.mint.opacity(0.32), lineWidth: 1)
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.mint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("Mac 任意门")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                Text("拖入保存 · 拖出使用")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                CountChip(
                    count: store.temporaryItems.count,
                    label: "一次性",
                    tint: .orange
                )
                CountChip(
                    count: store.permanentItems.count,
                    label: "素材",
                    tint: .mint
                )
            }

            Button {
                panelController.collapse()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("收起")
        }
    }

    private var scopeSwitcher: some View {
        HStack(spacing: 4) {
            scopeButton(
                for: .temporary,
                count: store.temporaryItems.count,
                isDropTarget: $isTemporaryTabDropTarget
            )
            scopeButton(
                for: .permanent,
                count: store.permanentItems.count,
                isDropTarget: $isPermanentTabDropTarget
            )
        }
        .padding(4)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func scopeButton(
        for section: PrimarySection,
        count: Int,
        isDropTarget: Binding<Bool>
    ) -> some View {
        let isSelected = primarySection == section

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                primarySection = section
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: section.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(section.subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(isSelected ? 0.54 : 0.38))
                }
                Spacer(minLength: 4)
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .white.opacity(0.48))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.58))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.white.opacity(0.15) : Color.clear,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        isDropTarget.wrappedValue ? .mint.opacity(0.86) : (isSelected ? .white.opacity(0.12) : .clear),
                        lineWidth: isDropTarget.wrappedValue ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onDrop(of: DropImporter.acceptedTypes, isTargeted: isDropTarget) { providers in
            acceptDrop(providers, into: section)
        }
        .accessibilityHint("将内容拖到此处可直接保存到\(section.title)区域")
    }

    private var temporaryContent: some View {
        itemArea(
            items: store.temporaryItems,
            emptyTitle: "拖入当前任务需要的内容",
            emptyDetail: "文字、图片、链接和文件会暂存于此，默认 24 小时后自动清理。",
            dropMessage: "松开放入一次性区域",
            isDropTarget: $isTemporaryDropTarget,
            allowsReordering: false
        ) { providers in
            dropImporter.importProviders(providers, into: .temporary)
        }
    }

    private var permanentContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("长期库")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("拖到左侧素材区或上方“长期”，会直接保存到长期区域")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Button {
                    isShowingNewMaterialSheet = true
                } label: {
                    Label("新建素材", systemImage: "plus")
                }
                .buttonStyle(GlassTextButtonStyle())

                if store.permanentItems.count > 1 {
                    Button(isOrderingPermanents ? "完成" : "排序") {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isOrderingPermanents.toggle()
                        }
                    }
                    .buttonStyle(GlassTextButtonStyle())
                }
            }

            HStack(alignment: .top, spacing: 10) {
                permanentMaterialsPane
                promptPane
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var permanentMaterialsPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            paneTitle(
                symbolName: "shippingbox.fill",
                title: "素材",
                detail: "文件 · 图片 · 文本 · 链接",
                tint: .mint
            )

            itemArea(
                items: store.permanentItems,
                emptyTitle: "保存需要反复使用的内容",
                emptyDetail: "拖入这里即可长期保留，不会自动过期。",
                dropMessage: "松开，直接长期保存",
                isDropTarget: $isPermanentDropTarget,
                allowsReordering: true
            ) { providers in
                dropImporter.importProviders(providers, into: .permanent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var promptPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            paneTitle(
                symbolName: "text.quote",
                title: "Prompt",
                detail: "整理可重复使用的指令",
                tint: .purple
            )

            promptPlaceholder
                .onDrop(of: DropImporter.acceptedTypes, isTargeted: $isPromptDropTarget) { _ in
                    store.showInformation("Prompt 创建将在阶段二启用。当前请将内容拖到左侧素材区。")
                    return false
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func paneTitle(
        symbolName: String,
        title: String,
        detail: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 4)
        }
    }

    private var promptPlaceholder: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.purple.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: isPromptDropTarget ? "arrow.down.to.line.compact" : "text.badge.plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.purple.opacity(0.92))
            }

            VStack(spacing: 4) {
                Text("Prompt 空间")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Text("阶段二开放创建与编辑")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Text("将网页或文档中的选中文字拖到这里，即可在后续版本整理成可复用 Prompt。")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.38))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 210)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .background(
            (isPromptDropTarget ? Color.purple.opacity(0.14) : Color.white.opacity(0.045)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isPromptDropTarget ? .purple.opacity(0.8) : .white.opacity(0.1),
                    style: StrokeStyle(lineWidth: isPromptDropTarget ? 1.5 : 1, dash: isPromptDropTarget ? [6, 5] : [])
                )
        )
    }

    @ViewBuilder
    private func itemArea(
        items: [PortalItem],
        emptyTitle: String,
        emptyDetail: String,
        dropMessage: String,
        isDropTarget: Binding<Bool>,
        allowsReordering: Bool,
        onDrop: @escaping ([NSItemProvider]) -> Void
    ) -> some View {
        ZStack {
            if items.isEmpty {
                emptyState(title: emptyTitle, detail: emptyDetail, isDropTarget: isDropTarget.wrappedValue)
            } else if isOrderingPermanents && allowsReordering {
                List {
                    ForEach(items) { item in
                        PortalItemCard(item: item, store: store)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 2)
                    }
                    .onMove(perform: store.movePermanentItems)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            } else {
                SlimScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(items) { item in
                            PortalItemCard(item: item, store: store)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if isDropTarget.wrappedValue {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(.mint.opacity(0.15))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.to.line.compact")
                                .font(.system(size: 20, weight: .semibold))
                            Text(dropMessage)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.mint)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(.mint.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
                    .padding(2)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .onDrop(of: DropImporter.acceptedTypes, isTargeted: isDropTarget) { providers in
            onDrop(providers)
            return true
        }
    }

    private func emptyState(title: String, detail: String, isDropTarget: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: isDropTarget ? "tray.and.arrow.down.fill" : "tray")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(isDropTarget ? .mint : .white.opacity(0.4))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.84))
            Text(detail)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.46))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 230)
        }
        .padding()
    }

    private func acceptDrop(_ providers: [NSItemProvider], into section: PrimarySection) -> Bool {
        withAnimation(.easeOut(duration: 0.2)) {
            primarySection = section
        }

        let scope: StorageScope = section == .temporary ? .temporary : .permanent
        dropImporter.importProviders(providers, into: scope)
        return true
    }
}

private struct FrostedPanelBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.17, blue: 0.2).opacity(0.68),
                            Color(red: 0.03, green: 0.05, blue: 0.07).opacity(0.56)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.24), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

private struct CountChip: View {
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

private struct GlassTextButtonStyle: ButtonStyle {
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

private struct SlimScrollView<Content: View>: View {
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
                                Color.clear
                                    .preference(
                                        key: SlimContentHeightKey.self,
                                        value: contentProxy.size.height
                                    )
                            }
                        )
                        .background(
                            GeometryReader { offsetProxy in
                                Color.clear
                                    .preference(
                                        key: SlimContentOffsetKey.self,
                                        value: offsetProxy.frame(in: .named("mac-any-door-scroll")).minY
                                    )
                            }
                        )
                }
                .coordinateSpace(name: "mac-any-door-scroll")
                .scrollIndicators(.hidden)
                .onPreferenceChange(SlimContentHeightKey.self) { height in
                    contentHeight = max(height, 1)
                }
                .onPreferenceChange(SlimContentOffsetKey.self) { offset in
                    contentOffset = max(-offset, 0)
                }

                if contentHeight > viewportHeight + 1 {
                    scrollIndicator(viewportHeight: viewport.size.height)
                }
            }
            .onAppear {
                viewportHeight = viewport.size.height
            }
            .onChange(of: viewport.size.height) { _, newHeight in
                viewportHeight = newHeight
            }
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
                        colors: [.white.opacity(isHovering ? 0.62 : 0.42), .white.opacity(isHovering ? 0.42 : 0.25)],
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

private enum NewMaterialKind: String, CaseIterable, Identifiable {
    case text
    case link

    var id: Self { self }

    var title: String {
        switch self {
        case .text:
            return "文本"
        case .link:
            return "链接"
        }
    }
}

private struct NewMaterialSheet: View {
    @ObservedObject var store: PortalStore

    @Environment(\.dismiss) private var dismiss
    @State private var kind: NewMaterialKind = .text
    @State private var value = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("新建长期素材")
                .font(.headline)

            Picker("类型", selection: $kind) {
                ForEach(NewMaterialKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            if kind == .text {
                TextEditor(text: $value)
                    .font(.body)
                    .frame(height: 130)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.secondary.opacity(0.25), lineWidth: 1)
                    )
            } else {
                TextField("https://example.com", text: $value)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func save() {
        switch kind {
        case .text:
            store.importText(value, into: .permanent)
        case .link:
            let normalized = value.contains("://") ? value : "https://\(value)"
            guard let url = URL(string: normalized), url.host != nil else {
                store.reportImportFailure("请输入有效链接。")
                return
            }
            store.importURL(url, into: .permanent)
        }
        dismiss()
    }
}

private struct NoticeBanner: View {
    let notice: PortalNotice
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
            Text(notice.text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
            Spacer(minLength: 6)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private var tint: Color {
        switch notice.style {
        case .success:
            return .mint
        case .error:
            return .red
        case .information:
            return .cyan
        }
    }

    private var symbolName: String {
        switch notice.style {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .information:
            return "info.circle.fill"
        }
    }
}
