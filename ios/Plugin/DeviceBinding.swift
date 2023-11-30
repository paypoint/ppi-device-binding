import Foundation


@objc public class DeviceBinding: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }

    @objc public func iOSComposeSMS(_ value: String) -> String {
        print(value)
        return value
    }

    @objc public func requestWithWrapper(_ value: String) -> String {
        print(value);
        return value;
    }

    @objc public func echo2(_ value: String) -> String {
        print(value)
        return value
    }
    
    @objc public func iOSSimPresent(_ value: String) -> String{
        print("iOSSimPresent 11111")
        print(value);
        return value;
    }
}
