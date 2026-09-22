import Foundation
import UniformTypeIdentifiers

public extension NSItemProvider {
    /// Extracts a file URL from NSItemProvider using Xlsx2SQL style (loadObject ofClass: URL.self).
    func extractURL(completion: @escaping (URL?) -> Void) {
        _ = self.loadObject(ofClass: URL.self) { url, _ in
            completion(url)
        }
    }
}

public extension Array where Element == NSItemProvider {
    /// Extracts all valid file URLs from an array of NSItemProvider items using Xlsx2SQL style, returning results on main queue.
    func extractURLs(completion: @escaping ([URL]) -> Void) {
        guard !self.isEmpty else {
            DispatchQueue.main.async {
                completion([])
            }
            return
        }
        
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()
        
        for provider in self {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                defer { group.leave() }
                if let url = url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(urls)
        }
    }
}
