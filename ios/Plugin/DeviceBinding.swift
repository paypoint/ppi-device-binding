import Foundation

@objc public class DeviceBinding: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
