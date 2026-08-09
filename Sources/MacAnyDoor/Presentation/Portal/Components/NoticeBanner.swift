import SwiftUI

struct NoticeBanner: View {
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
        case .success: return .mint
        case .error: return .red
        case .information: return .cyan
        }
    }

    private var symbolName: String {
        switch notice.style {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .information: return "info.circle.fill"
        }
    }
}
