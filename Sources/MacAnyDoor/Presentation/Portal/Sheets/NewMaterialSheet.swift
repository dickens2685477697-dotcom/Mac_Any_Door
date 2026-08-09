import SwiftUI

private enum NewMaterialKind: String, CaseIterable, Identifiable {
    case text
    case link

    var id: Self { self }

    var title: String {
        switch self {
        case .text: return "文本"
        case .link: return "链接"
        }
    }
}

struct NewMaterialSheet: View {
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
                Button("取消") { dismiss() }
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
