import Foundation

struct TagNoResolver {
    static func getCountForTag(directory: URL, tag: String) -> Int {
        let keys: [URLResourceKey] = [.nameKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var count = 0
        let targetPrefix = tag.lowercased()
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys))
            if resourceValues?.isDirectory == true { continue }
            
            let name = fileURL.lastPathComponent.lowercased()
            if name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") {
                let baseName = fileURL.deletingPathExtension().lastPathComponent.lowercased()
                if baseName == targetPrefix {
                    count += 1
                } else if baseName.hasPrefix("\(targetPrefix)_") {
                    let suffix = baseName.replacingOccurrences(of: "\(targetPrefix)_", with: "")
                    if Int(suffix) != nil {
                        count += 1
                    }
                }
            }
        }
        return count
    }
    
    static func getLastImageForTag(directory: URL, tag: String) -> URL? {
        let keys: [URLResourceKey] = [.nameKey, .isDirectoryKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
        ) else {
            return nil
        }
        
        let targetPrefix = tag.lowercased()
        var matchingFiles: [(URL, Date)] = []
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys))
            if resourceValues?.isDirectory == true { continue }
            
            let name = fileURL.lastPathComponent.lowercased()
            if name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") {
                let baseName = fileURL.deletingPathExtension().lastPathComponent.lowercased()
                let isMatch = baseName == targetPrefix || (baseName.hasPrefix("\(targetPrefix)_") && Int(baseName.replacingOccurrences(of: "\(targetPrefix)_", with: "")) != nil)
                
                if isMatch {
                    let date = resourceValues?.contentModificationDate ?? Date.distantPast
                    matchingFiles.append((fileURL, date))
                }
            }
        }
        
        return matchingFiles.sorted(by: { $0.1 > $1.1 }).first?.0
    }
    
    static func resolveFileName(directory: URL, tag: String) -> String {
        let nameWithoutExt = tag
        let fileManager = FileManager.default
        let path = directory.appendingPathComponent("\(nameWithoutExt).jpg")
        if !fileManager.fileExists(atPath: path.path) {
            return "\(nameWithoutExt).jpg"
        }
        
        var counter = 2
        while true {
            let candidate = "\(nameWithoutExt)_\(counter).jpg"
            let candidatePath = directory.appendingPathComponent(candidate)
            if !fileManager.fileExists(atPath: candidatePath.path) {
                return candidate
            }
            counter += 1
        }
    }
}
