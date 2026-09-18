import Foundation
import Combine
import SwiftUI

/**
 * Wrapper over UserDefaults for persisting app options and user preferences.
 */
final class PrefsManager: ObservableObject {
    static let shared = PrefsManager()

    @Published var minQty: Int {
        didSet { UserDefaults.standard.set(minQty, forKey: "min_qty") }
    }
    @Published var compression: String {
        didSet { UserDefaults.standard.set(compression, forKey: "compression") }
    }
    @Published var objectSize: String {
        didSet { UserDefaults.standard.set(objectSize, forKey: "object_size") }
    }
    @Published var sizeUnit: String {
        didSet { UserDefaults.standard.set(sizeUnit, forKey: "size_unit") }
    }
    @Published var showSize: Bool {
        didSet { UserDefaults.standard.set(showSize, forKey: "show_size") }
    }
    @Published var identifyObject: Bool {
        didSet { UserDefaults.standard.set(identifyObject, forKey: "identify_object") }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.minQty = defaults.object(forKey: "min_qty") as? Int ?? 1
        self.compression = defaults.string(forKey: "compression") ?? "JPEG_90"
        self.objectSize = defaults.string(forKey: "object_size") ?? ""
        self.sizeUnit = defaults.string(forKey: "size_unit") ?? "inch"
        self.showSize = defaults.bool(forKey: "show_size")
        self.identifyObject = defaults.bool(forKey: "identify_object")
    }
}
