import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

enum TemporaryRetention: Int, CaseIterable, Identifiable {
    case oneHour = 1
    case oneDay = 24
    case manual = 0

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .oneHour:
            return "保存 1 小时"
        case .oneDay:
            return "保存 24 小时"
        case .manual:
            return "手动清除"
        }
    }

    func expirationDate(from date: Date = .now) -> Date? {
        guard rawValue > 0 else { return nil }
        return date.addingTimeInterval(TimeInterval(rawValue * 60 * 60))
    }
}

enum PortalNoticeStyle {
    case success
    case error
    case information
}

struct PortalNotice: Identifiable {
    let id = UUID()
    let text: String
    let style: PortalNoticeStyle
}

@MainActor
final class PortalStore: NSObject, ObservableObject {
    @Published private(set) var items: [PortalItem] = []
    @Published private(set) var notice: PortalNotice?
    @Published private(set) var temporaryRetention: TemporaryRetention

    let fileStore: PortalFileStore
    private let defaults: UserDefaults
    private let retentionDefaultsKey = "temporaryRetentionHours"
    private var expiryTimer: Timer?

    init(rootURL: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedRetention = defaults.object(forKey: retentionDefaultsKey) as? Int
        self.temporaryRetention = TemporaryRetention(rawValue: savedRetention ?? TemporaryRetention.oneDay.rawValue) ?? .oneDay
        self.fileStore = PortalFileStore(rootURL: rootURL ?? Self.defaultRootURL())
        super.init()

        do {
            try fileStore.prepareDirectories()
            items = try fileStore.load()
            purgeExpired(showNotice: false)
        } catch {
            setNotice(error.localizedDescription, style: .error)
        }

        if rootURL == nil {
            expiryTimer = Timer.scheduledTimer(
                timeInterval: 15 * 60,
                target: self,
                selector: #selector(runExpiryCleanup(_:)),
                userInfo: nil,
                repeats: true
            )
        }
    }

    @objc
    private func runExpiryCleanup(_ timer: Timer) {
        purgeExpired()
    }

    var temporaryItems: [PortalItem] {
        items
            .filter { $0.scope == .temporary }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var permanentItems: [PortalItem] {
        items
            .filter { $0.scope == .permanent }
            .sorted {
                let leftOrder = $0.sortOrder ?? Int.max
                let rightOrder = $1.sortOrder ?? Int.max
                if leftOrder == rightOrder {
                    return $0.createdAt > $1.createdAt
                }
                return leftOrder < rightOrder
            }
    }

    var storageUsage: Int64 {
        fileStore.storageUsage()
    }

    func setTemporaryRetention(_ retention: TemporaryRetention) {
        temporaryRetention = retention
        defaults.set(retention.rawValue, forKey: retentionDefaultsKey)
        setNotice("一次性内容默认策略已更新为\(retention.displayName)。", style: .success)
    }

    func importText(_ text: String, into scope: StorageScope) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setNotice("不能保存空文本。", style: .error)
            return
        }

        let item = PortalItem(
            name: suggestedTextName(for: text),
            type: .text,
            scope: scope,
            textContent: text,
            createdAt: .now,
            updatedAt: .now,
            expiresAt: expirationDate(for: scope),
            sortOrder: sortOrder(for: scope)
        )
        add(item, successMessage: "已放入\(scope.displayName)区域。")
    }

    func importURL(_ url: URL, into scope: StorageScope) {
        if url.isFileURL {
            importFile(at: url, into: scope)
            return
        }

        let item = PortalItem(
            name: url.host(percentEncoded: false) ?? url.absoluteString,
            type: .url,
            scope: scope,
            originalURL: url,
            createdAt: .now,
            updatedAt: .now,
            expiresAt: expirationDate(for: scope),
            sortOrder: sortOrder(for: scope)
        )
        add(item, successMessage: "链接已放入\(scope.displayName)区域。")
    }

    func importFile(at sourceURL: URL, into scope: StorageScope) {
        let id = UUID()
        do {
            let storedFile = try fileStore.copyFile(at: sourceURL, id: id, scope: scope)
            let item = makeFileItem(
                id: id,
                originalName: sourceURL.lastPathComponent,
                storedFile: storedFile,
                scope: scope
            )
            add(item, rollbackFileFor: item, successMessage: "已放入\(scope.displayName)区域。")
        } catch {
            setNotice("无法保存 \(sourceURL.lastPathComponent)：\(error.localizedDescription)", style: .error)
        }
    }

    func importFileData(
        _ data: Data,
        originalName: String,
        contentTypeIdentifier: String?,
        into scope: StorageScope
    ) {
        let id = UUID()
        do {
            let storedFile = try fileStore.saveData(
                data,
                originalName: originalName,
                contentTypeIdentifier: contentTypeIdentifier,
                id: id,
                scope: scope
            )
            let item = makeFileItem(
                id: id,
                originalName: originalName,
                storedFile: storedFile,
                scope: scope
            )
            add(item, rollbackFileFor: item, successMessage: "已放入\(scope.displayName)区域。")
        } catch {
            setNotice("无法保存 \(originalName)：\(error.localizedDescription)", style: .error)
        }
    }

    func importClipboard(into scope: StorageScope = .temporary) {
        let pasteboard = NSPasteboard.general

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [:]) as? [NSURL], !urls.isEmpty {
            urls.map { $0 as URL }.forEach { importURL($0, into: scope) }
            return
        }

        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            let type = pasteboard.data(forType: .png) == nil ? UTType.tiff.identifier : UTType.png.identifier
            importFileData(imageData, originalName: "剪贴板图片.\(type == UTType.png.identifier ? "png" : "tiff")", contentTypeIdentifier: type, into: scope)
            return
        }

        if let text = pasteboard.string(forType: .string) {
            importText(text, into: scope)
            return
        }

        setNotice("剪贴板中没有可保存的文本、图片或链接。", style: .information)
    }

    func promote(_ item: PortalItem) {
        guard item.scope == .temporary, let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        let previousItems = items
        do {
            try fileStore.moveCachedFile(for: item, to: .permanent)
            var promoted = item
            promoted.scope = .permanent
            promoted.expiresAt = nil
            promoted.updatedAt = .now
            promoted.sortOrder = sortOrder(for: .permanent)
            items[index] = promoted

            guard persist() else {
                items = previousItems
                try? fileStore.moveCachedFile(for: promoted, to: .temporary)
                return
            }
            setNotice("已转为长期素材。", style: .success)
        } catch {
            setNotice("转为长期素材失败：\(error.localizedDescription)", style: .error)
        }
    }

    func rename(_ item: PortalItem, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        let previousItems = items
        items[index].name = trimmedName
        items[index].updatedAt = .now
        guard persist() else {
            items = previousItems
            return
        }
        setNotice("已重命名。", style: .success)
    }

    func delete(_ item: PortalItem) {
        remove([item], successMessage: "已删除内容。")
    }

    func clearTemporary() {
        remove(temporaryItems, successMessage: "已清空一次性区域。")
    }

    func purgeExpired(showNotice: Bool = true) {
        let expiredItems = temporaryItems.filter(\.isExpired)
        guard !expiredItems.isEmpty else { return }
        remove(expiredItems, successMessage: showNotice ? "已清理 \(expiredItems.count) 个过期内容。" : nil)
    }

    func movePermanentItems(from sourceOffsets: IndexSet, to destination: Int) {
        var ordered = permanentItems
        let selectedItems = sourceOffsets.map { ordered[$0] }
        for index in sourceOffsets.sorted(by: >) {
            ordered.remove(at: index)
        }

        let removedBeforeDestination = sourceOffsets.filter { $0 < destination }.count
        let insertionIndex = min(max(destination - removedBeforeDestination, 0), ordered.count)
        ordered.insert(contentsOf: selectedItems, at: insertionIndex)

        let previousItems = items
        for (index, item) in ordered.enumerated() {
            guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else { continue }
            items[itemIndex].sortOrder = index
            items[itemIndex].updatedAt = .now
        }

        guard persist() else {
            items = previousItems
            return
        }
    }

    func fileURL(for item: PortalItem) -> URL? {
        fileStore.cachedURL(for: item)
    }

    func dragProvider(for item: PortalItem) -> NSItemProvider {
        switch item.type {
        case .text:
            return NSItemProvider(object: (item.textContent ?? "") as NSString)
        case .url:
            if let url = item.originalURL {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider()
        case .image, .file:
            guard let fileURL = fileURL(for: item) else { return NSItemProvider() }
            let provider = NSItemProvider()
            provider.suggestedName = item.name
            provider.registerFileRepresentation(
                forTypeIdentifier: item.contentTypeIdentifier ?? UTType.data.identifier,
                fileOptions: [],
                visibility: .all
            ) { completion in
                completion(fileURL, true, nil)
                return nil
            }
            provider.registerObject(fileURL as NSURL, visibility: .all)
            return provider
        }
    }

    func dismissNotice() {
        notice = nil
    }

    func reportImportFailure(_ message: String) {
        setNotice(message, style: .error)
    }

    func showInformation(_ message: String) {
        setNotice(message, style: .information)
    }

    private func add(_ item: PortalItem, rollbackFileFor rollbackItem: PortalItem? = nil, successMessage: String) {
        let previousItems = items
        items.append(item)
        guard persist() else {
            items = previousItems
            if let rollbackItem {
                fileStore.deleteCachedFile(for: rollbackItem)
            }
            return
        }
        setNotice(successMessage, style: .success)
    }

    private func remove(_ targets: [PortalItem], successMessage: String?) {
        guard !targets.isEmpty else { return }
        let targetIDs = Set(targets.map(\.id))
        let previousItems = items
        items.removeAll { targetIDs.contains($0.id) }
        guard persist() else {
            items = previousItems
            return
        }
        targets.forEach(fileStore.deleteCachedFile)
        if let successMessage {
            setNotice(successMessage, style: .success)
        }
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            try fileStore.save(items)
            return true
        } catch {
            setNotice("本地保存失败：\(error.localizedDescription)", style: .error)
            return false
        }
    }

    private func makeFileItem(
        id: UUID,
        originalName: String,
        storedFile: StoredFile,
        scope: StorageScope
    ) -> PortalItem {
        PortalItem(
            id: id,
            name: originalName.isEmpty ? "未命名文件" : originalName,
            type: PortalItemType.from(contentTypeIdentifier: storedFile.contentTypeIdentifier),
            scope: scope,
            cachedFilename: storedFile.filename,
            contentTypeIdentifier: storedFile.contentTypeIdentifier,
            fileSize: storedFile.fileSize,
            createdAt: .now,
            updatedAt: .now,
            expiresAt: expirationDate(for: scope),
            sortOrder: sortOrder(for: scope)
        )
    }

    private func expirationDate(for scope: StorageScope) -> Date? {
        scope == .temporary ? temporaryRetention.expirationDate() : nil
    }

    private func sortOrder(for scope: StorageScope) -> Int? {
        guard scope == .permanent else { return nil }
        return (permanentItems.compactMap(\.sortOrder).max() ?? -1) + 1
    }

    private func suggestedTextName(for text: String) -> String {
        let firstContentLine = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !firstContentLine.isEmpty else { return "文本片段" }
        guard firstContentLine.count <= 40 else {
            return String(firstContentLine.prefix(40)) + "…"
        }
        return firstContentLine
    }

    private func setNotice(_ text: String, style: PortalNoticeStyle) {
        notice = PortalNotice(text: text, style: style)
    }

    private static func defaultRootURL() -> URL {
        let fileManager = FileManager.default
        let applicationSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        return applicationSupport.appending(path: "MacAnyDoor", directoryHint: .isDirectory)
    }
}
