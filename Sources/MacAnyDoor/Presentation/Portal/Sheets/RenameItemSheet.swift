import SwiftUI

struct RenameItemSheet: View {
    @Binding var proposedName: String
    let originalName: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重命名素材")
                .font(.headline)

            TextField("名称", text: $proposedName)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(proposedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private func save() {
        guard proposedName != originalName else {
            dismiss()
            return
        }
        onSave()
        dismiss()
    }
}
