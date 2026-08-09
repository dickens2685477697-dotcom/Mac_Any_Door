enum PortalSection: String, CaseIterable, Identifiable {
    case temporary
    case permanent

    var id: Self { self }

    var storageScope: StorageScope {
        switch self {
        case .temporary: return .temporary
        case .permanent: return .permanent
        }
    }

    var title: String {
        switch self {
        case .temporary: return "一次性"
        case .permanent: return "长期"
        }
    }

    var subtitle: String {
        switch self {
        case .temporary: return "默认保存 24 小时"
        case .permanent: return "长期保留"
        }
    }

    var symbolName: String {
        switch self {
        case .temporary: return "clock.arrow.circlepath"
        case .permanent: return "archivebox"
        }
    }
}
