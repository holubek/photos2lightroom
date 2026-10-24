import SwiftUI
import AppKit
import Photos
import UniformTypeIdentifiers

@MainActor
struct ContentView: View {
    @State private var status = "Ready"
    @State private var isReturningToPhotos = false
    @AppStorage("exportBatchManifest") private var exportBatchManifest = ""

    private static let filenameNormalizationLocale = Locale(identifier: "en_US_POSIX")

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 38))
                .foregroundStyle(.blue)

            Text("Photos to Lightroom")
                .font(.title2.bold())

            Text(status)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button("Send Selected RAWs to Lightroom") {
                sendToLightroom()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Return Lightroom Edits to Photos") {
                returnToPhotos()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text("Your original RAWs are never deleted.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 390)
    }

    private func sendToLightroom() {
        do {
            let timestampFormatter = DateFormatter()
            timestampFormatter.locale = Locale(identifier: "en_US_POSIX")
            timestampFormatter.dateFormat = "yyyyMMdd-HHmmss-SSS"

            let exportDate = Date()
            // A decreasing, fixed-width key sorts newer exports first. The leading
            // zero also places these folders before the original date-only names.
            let milliseconds = Int64(exportDate.timeIntervalSince1970 * 1_000)
            let reverseTimestamp = 9_999_999_999_999 - milliseconds
            let sortKey = String(format: "%013lld", reverseTimestamp)
            let folderName = "0-\(sortKey)-\(timestampFormatter.string(from: exportDate))"

            let exportRoot = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("PhotosToLR", isDirectory: true)
            let folder = exportRoot.appendingPathComponent(
                folderName,
                isDirectory: true
            )

            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )

            let script = """
            tell application "Photos"
                activate
                set selectedItems to selection
                if (count of selectedItems) is 0 then
                    error "Select one or more photos in Apple Photos first."
                end if

                set manifestText to ""
                repeat with selectedItem in selectedItems
                    set manifestText to manifestText & (id of selectedItem as text) & tab & (filename of selectedItem as text) & linefeed
                end repeat

                set destination to POSIX file "\(folder.path)" as alias
                export selectedItems to destination using originals true
                return manifestText
            end tell
            """

            var errorInfo: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else {
                throw WorkflowError.scriptCreation
            }

            let result = appleScript.executeAndReturnError(&errorInfo)

            if let errorInfo {
                throw WorkflowError.appleScript(
                    errorInfo[NSAppleScript.errorMessage] as? String
                        ?? "AppleScript could not export the selection."
                )
            }

            guard let manifestText = result.stringValue else {
                throw WorkflowError.missingAssetManifest
            }

            let items = try parseManifest(manifestText)
            try removeJPEGsPairedWithRAWFiles(in: folder)

            let batch = ExportBatch(
                folderPath: folder.path,
                items: items
            )
            try saveBatch(batch)

            let photoDescription = items.count == 1
                ? "1 original RAW exported."
                : "\(items.count) original RAWs exported."
            status = "\(photoDescription) Opening Lightroom…"
            NSWorkspace.shared.activateFileViewerSelecting([folder])

            if let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.adobe.Lightroom"
            ) {
                NSWorkspace.shared.openApplication(
                    at: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                ) { _, error in
                    Task { @MainActor in
                        if let error {
                            status = "Exported, but Lightroom could not open: \(error.localizedDescription)"
                        } else {
                            status = "Export edited JPEGs and MP4 videos back into this folder."
                        }
                    }
                }
            } else {
                status = "Originals exported. Export edited JPEGs and MP4 videos back into this folder."
            }
        } catch {
            status = "Could not export: \(error.localizedDescription)"
        }
    }

    private func parseManifest(_ manifestText: String) throws -> [ExportItem] {
        let items = manifestText.split(whereSeparator: \Character.isNewline).compactMap { line -> ExportItem? in
            let fields = line.split(
                separator: "\t",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard fields.count == 2,
                  !fields[0].isEmpty,
                  !fields[1].isEmpty else {
                return nil
            }

            return ExportItem(
                assetIdentifier: String(fields[0]),
                originalFilename: String(fields[1]),
                isApplied: false
            )
        }

        guard !items.isEmpty else {
            throw WorkflowError.missingAssetManifest
        }

        return items
    }

    private func saveBatch(_ batch: ExportBatch) throws {
        let data = try JSONEncoder().encode(batch)
        exportBatchManifest = data.base64EncodedString()
    }

    private func loadBatch() throws -> ExportBatch {
        guard !exportBatchManifest.isEmpty,
              let data = Data(base64Encoded: exportBatchManifest) else {
            throw WorkflowError.missingExportBatch
        }

        return try JSONDecoder().decode(ExportBatch.self, from: data)
    }

    private func removeJPEGsPairedWithRAWFiles(in folder: URL) throws {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentTypeKey],
            options: [.skipsHiddenFiles]
        )

        let rawBaseNames = try rawBaseNames(in: folder)

        for file in files {
            let contentType = try file.resourceValues(
                forKeys: [.contentTypeKey]
            ).contentType

            if contentType == .jpeg,
               rawBaseNames.contains(normalizedBaseName(for: file)) {
                try fileManager.removeItem(at: file)
            }
        }
    }

    private func jpegFiles(in folder: URL) throws -> [URL] {
        let files = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentTypeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return try files.filter { file in
            let values = try file.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { return false }
            // File-type registration can vary between accounts. Recognize the
            // standard extensions even when macOS supplies no JPEG content type.
            let fileExtension = file.pathExtension.lowercased()
            return fileExtension == "jpg" || fileExtension == "jpeg"
                || values.contentType?.conforms(to: .jpeg) == true
        }
    }

    private func rawBaseNames(in folder: URL) throws -> Set<String> {
        let files = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentTypeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        return try Set(files.compactMap { file -> String? in
            let values = try file.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { return nil }
            let isKnownRAW = ["cr3", "cr2", "dng"].contains(file.pathExtension.lowercased())
            guard isKnownRAW || values.contentType?.conforms(to: .rawImage) == true else {
                return nil
            }
            return normalizedBaseName(for: file)
        })
    }

    private func expectedJPEGBaseName(for originalFilename: String, rawBaseNames: Set<String>) -> String {
        let originalURL = URL(fileURLWithPath: originalFilename)
        let originalBaseName = normalizedBaseName(for: originalURL)
        // Photos may report the JPEG name of a RAW+JPEG asset even when it
        // exports a RAW. Use the exported RAW as evidence for same-name edits.
        let isJPEGOriginal = ["jpg", "jpeg"].contains(originalURL.pathExtension.lowercased())
        return isJPEGOriginal && !rawBaseNames.contains(originalBaseName)
            ? originalBaseName + "-2"
            : originalBaseName
    }

    private func normalizedBaseName(for file: URL) -> String {
        file.deletingPathExtension()
            .lastPathComponent
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Self.filenameNormalizationLocale
            )
    }

    private func returnToPhotos() {
        guard !isReturningToPhotos else { return }
        isReturningToPhotos = true
        Task {
            defer { isReturningToPhotos = false }
            do {
                var batch = try loadBatch()
                let pendingIndices = batch.items.indices.filter {
                    !batch.items[$0].isApplied
                }

                guard !pendingIndices.isEmpty else {
                    status = "All Lightroom edits in this batch have already been applied."
                    return
                }

                let exportFolder = URL(
                    fileURLWithPath: batch.folderPath,
                    isDirectory: true
                )
                let jpegFiles = try jpegFiles(in: exportFolder)
                let rawBaseNames = try rawBaseNames(in: exportFolder)
                let mp4Files = try FileManager.default.contentsOfDirectory(
                    at: exportFolder,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ).filter {
                    guard $0.pathExtension.lowercased() == "mp4" else { return false }
                    return try $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
                }
                let authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

                guard authorization == .authorized || authorization == .limited else {
                    status = "Allow full Photos access in System Settings to apply the edits."
                    return
                }

                let identifiers = pendingIndices.map {
                    batch.items[$0].assetIdentifier
                }
                let fetchResult = PHAsset.fetchAssets(
                    withLocalIdentifiers: identifiers,
                    options: nil
                )
                var assetsByIdentifier: [String: PHAsset] = [:]
                fetchResult.enumerateObjects { asset, _, _ in
                    assetsByIdentifier[asset.localIdentifier] = asset
                }

                var appliedCount = 0
                var failures: [String] = []

                for index in pendingIndices {
                    let item = batch.items[index]
                    let displayName = item.originalFilename
                    guard let asset = assetsByIdentifier[item.assetIdentifier] else {
                        failures.append("\(displayName): Photos asset not found")
                        continue
                    }
                    let isVideo = asset.mediaType == .video
                    let originalURL = URL(fileURLWithPath: item.originalFilename)
                    let expectedJPEGName = expectedJPEGBaseName(
                        for: item.originalFilename,
                        rawBaseNames: rawBaseNames
                    )
                    let matches = isVideo
                        ? mp4Files.filter {
                            normalizedBaseName(for: $0) == normalizedBaseName(for: originalURL)
                        }
                        : jpegFiles.filter { normalizedBaseName(for: $0) == expectedJPEGName }
                    let fileType = isVideo ? "MP4" : "JPEG"

                    guard !matches.isEmpty else {
                        let expectedName = isVideo
                            ? originalURL.deletingPathExtension().lastPathComponent
                            : expectedJPEGName
                        failures.append(
                            "\(displayName): \(fileType) not found. Expected \(expectedName).\(isVideo ? "mp4" : "jpg or .jpeg") directly in \(exportFolder.path)"
                        )
                        continue
                    }
                    guard matches.count == 1, let editedURL = matches.first else {
                        failures.append("\(displayName): multiple matching \(fileType) files")
                        continue
                    }
                    // Do not mistake an exported MP4 original for a Lightroom edit.
                    guard !isVideo || editedURL.lastPathComponent.caseInsensitiveCompare(
                        originalURL.lastPathComponent
                    ) != .orderedSame else {
                        failures.append("\(displayName): MP4 has the original filename; export from a MOV original")
                        continue
                    }
                    guard isVideo || asset.canPerform(.content) else {
                        failures.append("\(displayName): asset is not editable")
                        continue
                    }

                    do {
                        status = "Returning item \(appliedCount + 1) of \(pendingIndices.count)…"
                        if isVideo {
                            try await importVideo(from: editedURL, copyingMetadataFrom: asset)
                        } else {
                            try await applyEdit(from: editedURL, to: asset)
                        }
                        batch.items[index].isApplied = true
                        try saveBatch(batch)
                        appliedCount += 1
                    } catch {
                        failures.append("\(displayName): \(error.localizedDescription)")
                    }
                }

                if failures.isEmpty {
                    status = "\(appliedCount) Lightroom item(s) returned. Videos imported as new items; originals preserved."
                } else {
                    status = "Applied \(appliedCount) edit(s). Skipped \(failures.count): \(failures.joined(separator: "; "))."
                }
            } catch {
                status = "Could not apply edits: \(error.localizedDescription)"
            }
        }
    }

    private func importVideo(from fileURL: URL, copyingMetadataFrom asset: PHAsset) async throws {
        // Set metadata in the creation transaction so the new video never loses
        // the original's Photos date/time or location, even if the MP4 omits them.
        let creationDate = asset.creationDate
        let location = asset.location
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .video, fileURL: fileURL, options: nil)
            request.creationDate = creationDate
            request.location = location
        }
    }

    private func applyEdit(from fileURL: URL, to asset: PHAsset) async throws {
        let editingInput = try await contentEditingInput(for: asset)
        let editingOutput = PHContentEditingOutput(
            contentEditingInput: editingInput
        )

        try FileManager.default.copyItem(
            at: fileURL,
            to: editingOutput.renderedContentURL
        )

        let adjustmentDetails = [
            "editor": "Adobe Lightroom",
            "fileName": fileURL.lastPathComponent
        ]
        let adjustmentData = try JSONSerialization.data(
            withJSONObject: adjustmentDetails
        )
        editingOutput.adjustmentData = PHAdjustmentData(
            formatIdentifier: "com.photostolightroom.lightroom-edit",
            formatVersion: "1.0",
            data: adjustmentData
        )

        try await PHPhotoLibrary.shared().performChanges {
            let changeRequest = PHAssetChangeRequest(for: asset)
            changeRequest.contentEditingOutput = editingOutput
        }
    }

    private func contentEditingInput(for asset: PHAsset) async throws -> PHContentEditingInput {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        options.canHandleAdjustmentData = { _ in false }

        return try await withCheckedThrowingContinuation { continuation in
            asset.requestContentEditingInput(with: options) { input, _ in
                if let input {
                    continuation.resume(returning: input)
                } else {
                    continuation.resume(throwing: WorkflowError.editingInputUnavailable)
                }
            }
        }
    }
}

private struct ExportBatch: Codable {
    let folderPath: String
    var items: [ExportItem]
}

private struct ExportItem: Codable {
    let assetIdentifier: String
    let originalFilename: String
    var isApplied: Bool
}

private enum WorkflowError: LocalizedError {
    case scriptCreation
    case appleScript(String)
    case missingAssetManifest
    case missingExportBatch
    case editingInputUnavailable

    var errorDescription: String? {
        switch self {
        case .scriptCreation:
            return "Could not create the Photos automation script."
        case .appleScript(let message):
            return message
        case .missingAssetManifest:
            return "Photos did not return identifiers and filenames for the selected photos."
        case .missingExportBatch:
            return "Send one or more photos to Lightroom before applying edits."
        case .editingInputUnavailable:
            return "Photos could not prepare the original photo for editing."
        }
    }
}

#Preview {
    ContentView()
}
