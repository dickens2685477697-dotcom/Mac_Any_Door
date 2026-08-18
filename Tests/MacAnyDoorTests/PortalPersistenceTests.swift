import Foundation
import UniformTypeIdentifiers
import XCTest
@testable import MacAnyDoor

final class PortalFileStoreTests: XCTestCase {
    func testCopyMoveAndDeleteCachedFile() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let sourceURL = rootURL.appending(path: "sample.txt")
        try Data("hello portal".utf8).write(to: sourceURL)

        let fileStore = PortalFileStore(rootURL: rootURL.appending(path: "Storage", directoryHint: .isDirectory))
        let id = UUID()
        let stored = try fileStore.copyFile(at: sourceURL, id: id, scope: .temporary)
        var item = PortalItem(
            id: id,
            name: "sample.txt",
            type: .file,
            scope: .temporary,
            cachedFilename: stored.filename,
            fileSize: stored.fileSize
        )

        let temporaryURL = try XCTUnwrap(fileStore.cachedURL(for: item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryURL.path))
        XCTAssertEqual(try Data(contentsOf: temporaryURL), Data("hello portal".utf8))

        try fileStore.moveCachedFile(for: item, to: .permanent)
        item.scope = .permanent
        let permanentURL = try XCTUnwrap(fileStore.cachedURL(for: item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: permanentURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.path))

        fileStore.deleteCachedFile(for: item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: permanentURL.path))
    }

    func testMetadataRoundTrip() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let fileStore = PortalFileStore(rootURL: rootURL)
        let expected = PortalItem(
            name: "研究链接",
            type: .url,
            scope: .permanent,
            originalURL: URL(string: "https://example.com/paper")!,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
            sortOrder: 2
        )

        try fileStore.save([expected])
        XCTAssertEqual(try fileStore.load(), [expected])
    }

    func testFolderIsCopiedAsOwnedContent() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let sourceFolder = rootURL.appending(path: "research", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        try Data("notes".utf8).write(to: sourceFolder.appending(path: "notes.txt"))

        let fileStore = PortalFileStore(rootURL: rootURL.appending(path: "Storage", directoryHint: .isDirectory))
        let id = UUID()
        let stored = try fileStore.copyFile(at: sourceFolder, id: id, scope: .temporary)
        let item = PortalItem(
            id: id,
            name: "research",
            type: .file,
            scope: .temporary,
            cachedFilename: stored.filename,
            contentTypeIdentifier: stored.contentTypeIdentifier
        )

        let cachedFolder = try XCTUnwrap(fileStore.cachedURL(for: item))
        XCTAssertEqual(stored.contentTypeIdentifier, UTType.folder.identifier)
        XCTAssertEqual(try Data(contentsOf: cachedFolder.appending(path: "notes.txt")), Data("notes".utf8))
    }

    private func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "MacAnyDoorTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

@MainActor
final class PortalStoreTests: XCTestCase {
    func testStorePersistsTemporaryTextAndPromotesIt() throws {
        let rootURL = makeTemporaryDirectory()
        let suiteName = "MacAnyDoorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PortalStore(rootURL: rootURL, defaults: defaults)
        store.importText("请分析这篇论文", into: .temporary)

        let temporaryItem = try XCTUnwrap(store.temporaryItems.first)
        XCTAssertEqual(temporaryItem.textContent, "请分析这篇论文")
        XCTAssertNotNil(temporaryItem.expiresAt)

        store.promote(temporaryItem)
        XCTAssertTrue(store.temporaryItems.isEmpty)
        XCTAssertEqual(store.permanentItems.count, 1)
        XCTAssertNil(store.permanentItems[0].expiresAt)

        let reloadedStore = PortalStore(rootURL: rootURL, defaults: defaults)
        XCTAssertEqual(reloadedStore.permanentItems.count, 1)
        XCTAssertEqual(reloadedStore.permanentItems[0].textContent, "请分析这篇论文")
    }

    func testImportedMarkdownDataKeepsOriginalFilenameAndType() throws {
        let rootURL = makeTemporaryDirectory()
        let suiteName = "MacAnyDoorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PortalStore(rootURL: rootURL, defaults: defaults)
        let markdown = Data("# 任意门\n\n保留 Markdown 格式。".utf8)
        store.importFileData(
            markdown,
            originalName: "README.md",
            contentTypeIdentifier: UTType.data.identifier,
            into: .temporary
        )

        let item = try XCTUnwrap(store.temporaryItems.first)
        XCTAssertEqual(item.name, "README.md")
        XCTAssertEqual(item.contentTypeIdentifier, UTType(filenameExtension: "md")?.identifier)
        let storedURL = try XCTUnwrap(store.fileURL(for: item))
        XCTAssertEqual(try Data(contentsOf: storedURL), markdown)
    }

    func testCustomAreaNameAndFilesPersistSeparatelyFromPermanentMaterials() throws {
        let rootURL = makeTemporaryDirectory()
        let suiteName = "MacAnyDoorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PortalStore(rootURL: rootURL, defaults: defaults)
        XCTAssertEqual(store.materialAreaName, "素材")
        XCTAssertEqual(store.customAreaName, "Prompt")

        store.renameMaterialArea(to: "收藏")
        store.renameCustomArea(to: "研究库")
        store.importFileData(
            Data("自定义区域内容".utf8),
            originalName: "notes.md",
            contentTypeIdentifier: UTType.data.identifier,
            into: .custom
        )

        let item = try XCTUnwrap(store.customItems.first)
        XCTAssertEqual(item.scope, .custom)
        let storedURL = try XCTUnwrap(store.fileURL(for: item))
        XCTAssertEqual(storedURL.deletingLastPathComponent().lastPathComponent, "Custom")
        XCTAssertEqual(try Data(contentsOf: storedURL), Data("自定义区域内容".utf8))

        store.renameCustomArea(to: "资料库")
        XCTAssertEqual(store.fileURL(for: item), storedURL)

        let reloadedStore = PortalStore(rootURL: rootURL, defaults: defaults)
        XCTAssertEqual(reloadedStore.materialAreaName, "收藏")
        XCTAssertEqual(reloadedStore.customAreaName, "资料库")
        let reloadedItem = try XCTUnwrap(reloadedStore.customItems.first)
        XCTAssertEqual(reloadedItem.id, item.id)
        XCTAssertEqual(reloadedItem.name, item.name)
        XCTAssertEqual(reloadedItem.scope, .custom)
        XCTAssertEqual(reloadedItem.cachedFilename, item.cachedFilename)
    }

    func testExpiredTemporaryItemsArePurgedOnStartup() throws {
        let rootURL = makeTemporaryDirectory()
        let suiteName = "MacAnyDoorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            defaults.removePersistentDomain(forName: suiteName)
        }

        let fileStore = PortalFileStore(rootURL: rootURL)
        let expired = PortalItem(
            name: "过期文本",
            type: .text,
            scope: .temporary,
            textContent: "will disappear",
            expiresAt: Date().addingTimeInterval(-60)
        )
        try fileStore.save([expired])

        let store = PortalStore(rootURL: rootURL, defaults: defaults)
        XCTAssertTrue(store.temporaryItems.isEmpty)
        XCTAssertTrue(try fileStore.load().isEmpty)
    }

    private func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "MacAnyDoorTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

}
