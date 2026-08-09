import AppKit
import SwiftUI

struct PortalItemCard: View {
    let item: PortalItem
    @ObservedObject var store: PortalStore
    @ObservedObject var panelController: NotchPanelController
    let itemProviderFactory: PortalItemProviderFactory

    @State private var isShowingRenameSheet = false
    @State private var proposedName = ""

    var body: some View {
        HStack(spacing: 11) {
            leadingVisual

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)

                Text(item.contentSummary)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)

                HStack(spacing: 7) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                        Text(item.createdAt, style: .relative)
                    }

                    if let expiresAt = item.expiresAt {
                        Text(expiresAt, style: .relative)
                            .foregroundStyle(item.isExpired ? .red : .orange)
                    }
                }
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
            }

            Spacer(minLength: 4)

            HStack(spacing: 5) {
                if item.scope == .temporary {
                    Button {
                        store.promote(item)
                    } label: {
                        Image(systemName: "archivebox")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.mint)
                            .frame(width: 25, height: 25)
                            .background(.mint.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("转为长期素材")
                }

                Menu {
                    if item.scope == .temporary {
                        Button("转为长期素材", systemImage: "arrow.right.circle") {
                            store.promote(item)
                        }
                    }
                    Button("重命名", systemImage: "pencil") {
                        presentRenameSheet()
                    }
                    Divider()
                    Button("删除", systemImage: "trash", role: .destructive) {
                        store.delete(item)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.56))
                        .frame(width: 25, height: 25)
                        .background(.white.opacity(0.07), in: Circle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.white.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(.white.opacity(0.13), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onDrag {
            itemProviderFactory.provider(for: item)
        }
        .contextMenu {
            if item.scope == .temporary {
                Button("转为长期素材") {
                    store.promote(item)
                }
            }
            Button("重命名") {
                presentRenameSheet()
            }
            Divider()
            Button("删除") {
                store.delete(item)
            }
        }
        .sheet(isPresented: $isShowingRenameSheet, onDismiss: {
            panelController.endModalInteraction()
        }) {
            RenameItemSheet(
                proposedName: $proposedName,
                originalName: item.name,
                onSave: { store.rename(item, to: proposedName) }
            )
        }
    }

    private func presentRenameSheet() {
        panelController.beginModalInteraction()
        proposedName = item.name
        isShowingRenameSheet = true
    }

    @ViewBuilder
    private var leadingVisual: some View {
        if item.type == .image,
           let url = store.fileURL(for: item),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
        } else {
            Image(systemName: item.type.symbolName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(iconTint)
                .frame(width: 42, height: 42)
                .background(iconTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(iconTint.opacity(0.24), lineWidth: 1)
                )
        }
    }

    private var iconTint: Color {
        switch item.type {
        case .text:
            return .mint
        case .url:
            return .cyan
        case .image:
            return .pink
        case .file:
            return .orange
        }
    }
}
