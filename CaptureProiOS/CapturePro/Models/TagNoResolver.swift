import Foundation
import UIKit

/**
 * Resolves directory structure and counts saved images for given Tag No.
 * Directory structure: Documents/CapturePro/{dd-MM-yyyy & Username}/{TagNo}/
 */
final class TagNoResolver {
    static let shared = TagNoResolver()
    private init() {}

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func getDateFolderName(username: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dateStr = formatter.string(from: Date())
        return "\(dateStr) & \(username)"
    }

    func getTagFolderURL(username: String, tagNo: String) -> URL {
        let dateFolder = getDateFolderName(username: username)
        let cleanTag = tagNo.trimmingCharacters(in: .whitespacesAndNewlines)
        return documentsDirectory
            .appendingPathComponent("CapturePro")
            .appendingPathComponent(dateFolder)
            .appendingPathComponent(cleanTag.isEmpty ? "Uncategorized" : cleanTag)
    }

    func getCountForTag(username: String, tagNo: String) -> Int {
        let tagFolder = getTagFolderURL(username: username, tagNo: tagNo)
        guard let files = try? FileManager.default.contentsOfDirectory(at: tagFolder, includingPropertiesForKeys: nil) else {
            return 0
        }
        return files.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" }.count
    }

    func getLastImageURLForTag(username: String, tagNo: String) -> URL? {
        let tagFolder = getTagFolderURL(username: username, tagNo: tagNo)
        guard let files = try? FileManager.default.contentsOfDirectory(at: tagFolder, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return nil
        }
        let images = files.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" }
        return images.max { url1, url2 -> Bool in
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return date1 < date2
        }
    }

    func saveCapturedImage(_ image: UIImage, username: String, tagNo: String, compression: String) -> URL? {
        let folder = getTagFolderURL(username: username, tagNo: tagNo)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "IMG_\(timestamp).jpg"
        let fileURL = folder.appendingPathComponent(filename)

        var compressionQuality: CGFloat = 0.90
        if compression.contains("100") { compressionQuality = 1.0 }
        else if compression.contains("80") { compressionQuality = 0.80 }
        else if compression.contains("70") { compressionQuality = 0.70 }

        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return nil }
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing image: \(error)")
            return nil
        }
    }
}
