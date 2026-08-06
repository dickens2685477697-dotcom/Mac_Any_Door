import AppKit
import Foundation
import UniformTypeIdentifiers

/// Converts AppKit drag providers into the small, explicit set of PortalItem
/// inputs. The source app controls the payload; this importer never reads
/// unrelated pasteboard history.
@MainActor
final class DropImporter {
    static let acceptedTypes: [UTType] = [
        .fileURL,
        .url,
        .image,
        .pdf,
        .utf8PlainText,
        .plainText,
        .text,
        .data
    ]

    private let store: PortalStore

    init(store: PortalStore) {
        self.store = store
    }

    func importProviders(_ providers: [NSItemProvider], into scope: StorageScope) {
        guard !providers.isEmpty else {
            store.reportImportFailure("没有收到可保存的拖动内容。")
            return
        }

        providers.forEach { importProvider($0, into: scope) }
    }

    private func importProvider(_ provider: NSItemProvider, into scope: StorageScope) {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            importFileURL(from: provider, into: scope)
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            importURL(from: provider, into: scope)
            return
        }

        if let imageType = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .image) == true
        }) {
            importData(from: provider, typeIdentifier: imageType, fallbackName: "拖入图片", into: scope)
            return
        }

        if let textType = [UTType.utf8PlainText, .plainText, .text]
            .first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) {
            importText(from: provider, typeIdentifier: textType.identifier, into: scope)
            return
        }

        store.reportImportFailure("无法识别这段拖动内容。")
    }

    private func importFileURL(from provider: NSItemProvider, into scope: StorageScope) {
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] object, error in
            guard let self else { return }
            guard let sourceURL = Self.url(from: object) else {
                Task { @MainActor in
                    self.store.reportImportFailure(error?.localizedDescription ?? "无法读取拖入的文件。")
                }
                return
            }

            do {
                // NSItemProvider may revoke its temporary representation when
                // this callback returns. Copy it once to a short-lived staging
                // directory so both regular files and folders can be imported
                // on the main actor without retaining the source URL.
                let stagingDirectory = FileManager.default.temporaryDirectory
                    .appending(path: "MacAnyDoorDrop-\(UUID().uuidString)", directoryHint: .isDirectory)
                let stagedURL = stagingDirectory.appending(path: sourceURL.lastPathComponent, directoryHint: .notDirectory)
                try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: sourceURL, to: stagedURL)

                Task { @MainActor in
                    self.store.importFile(at: stagedURL, into: scope)
                    try? FileManager.default.removeItem(at: stagingDirectory)
                }
            } catch {
                Task { @MainActor in
                    self.store.reportImportFailure("无法读取 \(sourceURL.lastPathComponent)：\(error.localizedDescription)")
                }
            }
        }
    }

    private func importURL(from provider: NSItemProvider, into scope: StorageScope) {
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] object, error in
            guard let self else { return }
            guard let url = Self.url(from: object) else {
                Task { @MainActor in
                    self.store.reportImportFailure(error?.localizedDescription ?? "无法读取拖入的链接。")
                }
                return
            }

            Task { @MainActor in
                self.store.importURL(url, into: scope)
            }
        }
    }

    private func importText(from provider: NSItemProvider, typeIdentifier: String, into scope: StorageScope) {
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] object, error in
            guard let self else { return }
            let text: String?
            if let string = object as? String {
                text = string
            } else if let string = object as? NSString {
                text = string as String
            } else if let data = object as? Data {
                text = String(data: data, encoding: .utf8)
            } else {
                text = nil
            }

            guard let text else {
                Task { @MainActor in
                    self.store.reportImportFailure(error?.localizedDescription ?? "无法读取拖入的文字。")
                }
                return
            }

            Task { @MainActor in
                self.store.importText(text, into: scope)
            }
        }
    }

    private func importData(
        from provider: NSItemProvider,
        typeIdentifier: String,
        fallbackName: String,
        into scope: StorageScope
    ) {
        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] data, error in
            guard let self else { return }
            guard let data else {
                Task { @MainActor in
                    self.store.reportImportFailure(error?.localizedDescription ?? "无法读取拖入的图片。")
                }
                return
            }

            let type = UTType(typeIdentifier)
            let extensionPart = type?.preferredFilenameExtension
            let name = extensionPart.map { "\(fallbackName).\($0)" } ?? fallbackName
            Task { @MainActor in
                self.store.importFileData(data, originalName: name, contentTypeIdentifier: typeIdentifier, into: scope)
            }
        }
    }

    nonisolated private static func url(from object: NSSecureCoding?) -> URL? {
        if let url = object as? URL {
            return url
        }
        if let url = object as? NSURL {
            return url as URL
        }
        if let data = object as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        return nil
    }
}
