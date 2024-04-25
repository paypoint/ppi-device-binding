import Foundation
import Capacitor
import MessageUI
import Alamofire
import CommonCrypto

import Security
import CoreTelephony

class PinnedCertificatesTrustEvaluator: ServerTrustEvaluating {
    
    private let localPublicKeys: [String]
    
    init(publicKeys: [String]) {
        self.localPublicKeys = publicKeys
    }
    
    func evaluate(_ trust: SecTrust, forHost host: String) throws {
        print("Evaluate Host : ", host)
        // Extract the server's public key
        guard let serverPublicKey = PinnedCertificatesTrustEvaluator.extractPublicKey(from: trust) else {
            throw AFError.serverTrustEvaluationFailed(reason: .noRequiredEvaluator(host: host))
        }
        
        // Compare the server's public key with the locally stored public key
        if localPublicKeys.contains(serverPublicKey) {
            // Public key pinning successful
        } else {
            throw AFError.serverTrustEvaluationFailed(reason: .noRequiredEvaluator(host: host))
        }
    }
    
    static let rsa2048Asn1Header: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ]
    
    static func sha256(data: Data) -> String {
        var keyWithHeader = Data(rsa2048Asn1Header)
        keyWithHeader.append(data)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        keyWithHeader.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(keyWithHeader.count), &hash)
        }
        return Data(hash).base64EncodedString()
    }
    
    static func extractPublicKey(from trust: SecTrust) -> String? {
        
        guard let certificate = SecTrustGetCertificateAtIndex(trust, 0) else {
            return nil
        }
        
//        print("certificate 111 : ", certificate);
        
        var publicKey: SecKey?
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        
        if status == errSecSuccess {
            publicKey = SecTrustCopyPublicKey(trust!)
        }
        
        // Convert the public key to data
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey!, &error) as Data? else {
            return nil
        }
//        print("certificate 222 : ", publicKeyData.base64EncodedString());
        
        let data: Data = publicKeyData as Data
        let serverHashKey = PinnedCertificatesTrustEvaluator.sha256(data: data)
        
//        print("certificate 333 : ", serverHashKey);
        
        return serverHashKey;
//        return publicKeyData.base64EncodedString()
    }
}

@objc(DeviceBindingPlugin)
public class DeviceBindingPlugin: CAPPlugin, MFMessageComposeViewControllerDelegate {
    
    private let implement = DeviceBinding()
    private var autoCancelTimer: Timer? // Instance variable to store the timer
    
    private lazy var afSession: Session = {
        
    
        let evaluators: [String: ServerTrustEvaluating] = [
            "mb2cv1.paypointz.com": PinnedCertificatesTrustEvaluator(
                publicKeys: ["hsL+5qyGbPCknWO9N5DrnopUwL3ba1nUDLYoqNOfxdQ=","hsL+5qyGbPCknWO9N5DrnopUwL3ba1nUDLYoqNOfxdQ="]
            )
        ]

        let manager = ServerTrustManager(evaluators: evaluators)
        return Session(serverTrustManager: manager)
    }()
    
    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getValue("value") ?? ""
        call.resolve(["value": implement.echo(value as! String)])
    }
    
    @objc func iOSComposeSMS(_ call: CAPPluginCall) {
        guard let messageBody = call.getString("messageContent") else {
            call.reject("INVALID_BODY", "Message body is missing")
            return
        }
        
        let recipient = call.getString("destinationNumber") ?? "8655874341" // Default phone number
        
        if MFMessageComposeViewController.canSendText() {
            DispatchQueue.main.async {
                let composeVC = MFMessageComposeViewController()
                composeVC.body = messageBody
                composeVC.recipients = [recipient]
                composeVC.messageComposeDelegate = self
                if #available(iOS 17.0, *) {
                    composeVC.setUPIVerificationCodeSendCompletion { result in
                        NSLog("UPI send callback - message sent: \(result)")
                    }
                } else {
                    // Fallback on earlier versions
                }
                        
                
                if let rootViewController = self.bridge?.viewController {
                    rootViewController.present(composeVC, animated: true, completion: nil)
                    
                    self.autoCancelTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
                        composeVC.dismiss(animated: false) {
                            self?.sendSMSResultEvent(status: .cancelled)
                        }
                        self?.autoCancelTimer?.invalidate()
                        self?.autoCancelTimer = nil
                    }
                }
                
                call.resolve(["status": "success"])
            }
        } else {
            call.reject("SMS_NOT_SUPPORTED", "SMS is not supported on this device")
        }
    }
    
    func sendSMSResultEvent(status: MessageComposeResult) {
        var statusString = ""
        switch status {
        case .sent:
            statusString = "sent"
        case .cancelled:
            statusString = "cancelled"
        case .failed:
            statusString = "failed"
        @unknown default:
            statusString = "unknown"
        }
        
        let jsEvent = "window.dispatchEvent(new CustomEvent('onSMSComposeResult', { detail: { status: '\(statusString)' } }));"
        self.bridge?.webView?.evaluateJavaScript(jsEvent, completionHandler: nil)
    }
    
    public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
        sendSMSResultEvent(status: result)
    }
    
    @objc public func requestWithWrapper(_ call: CAPPluginCall) {
        
        guard let url = call.getString("url"),
        let method = call.getString("method")?.uppercased() else {
            call.reject("Invalid parameters for requestWithWrapper")
            return
        }
            
        // Request headers
        var requestHeaders: HTTPHeaders = [:]
        
        // Check if custom headers are provided
        if let headers = call.getObject("headers") as? [String: String] {
            // If custom headers are provided, override the request headers
            requestHeaders = HTTPHeaders(headers)
        }
//        
        
//        let requestHeaders: HTTPHeaders = [
//            "MobileNo": "8655874341",
//            "Content-Type": "application/json",
//            "Authorization":"Bearer xAEc55T9v7A7_S6sB5bOejDCHQAJvNSSWw2AZ7O7SokWM7ONjTFKXwQvjMGQCeAerlqHGog9FK0uEY1g8eUnmdp69sunIh060Jo_siztQAb15O9Kiy_oorNQC6NMAI6dwrSb3TsWVZHYM7BK6TWYw5_T9yiGmdNn5XTDX6U-SuhzbyUVrPT4uk1lWyOVPz3HGsM7pRvynlLRl1A7ectVIqbu5q93JlzyDta6T4fGpj2GWPkL1Rn0dRGBY7HiTD_r",
//            "origin":"capacitor://localhost",
//            "CompanyID": "5t6yQbRy/HM=",
//        ]
        // Request parameters
        var requestParameters: Parameters = [:]
        
        // Check if custom parameters are provided
        if let parameters = call.getObject("parameters") {
            requestParameters = parameters
        }

        
        
        var request: DataRequest
        print("METHOD : ", method);
        if method == "POST" {
            print("--> headers : ", requestHeaders)
            
            print("--> headers : ")
            for header in requestHeaders {
                print("xxa : \(header.name): \(header.value)")
            }


            // Handle POST request with headers and parameters
            request = afSession.request(
                url,
                method: .post,
                parameters: requestParameters,
                encoding: JSONEncoding.default,
                headers: requestHeaders
            )
        } else {
            // Handle other methods (GET, etc.) with headers and parameters
            request = afSession.request(
                url,
                method: HTTPMethod(rawValue: method),
                parameters: requestParameters,
                headers: requestHeaders
            )
        }

        request.validate().responseData { response in
            switch response.result {
            case .success(let data):
                // Check if the data can be parsed as JSON
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    if let jsonString = String(data: data, encoding: .utf8) {
                        // JSON data
                        call.resolve(["response": json, "responseString": jsonString])
                    } else {
                        // Plan data
                        // Handle plan data here
                        // For example, you can convert it to a string and include it in the response
                        if String(data: data, encoding: .utf8) != nil {
                            call.resolve(["response": data])
                        } else {
                            call.reject("PLAN_DATA_ERROR", "Error parsing plan data")
                        }
                    }
                } catch {
                    // Plan data (assuming it doesn't parse as JSON)
                    if let planString = String(data: data, encoding: .utf8) {
                        call.resolve(["response": planString])
                    } else {
                        call.reject("PLAN_DATA_ERROR", "Error parsing plan data")
                    }
                }
            case .failure(let error):
                print("SSL----ERROR : ")
                switch error {
                case .serverTrustEvaluationFailed(let reason):
                    print("SSL-Cert-Pinning Failed: \(reason)")
                    call.reject("SSL_CERT_PINNING_FAILED", "SSL Certificate Pinning Failed")
                default:
                    call.reject("NETWORK_REQUEST_ERROR", "Error in network request: \(error.localizedDescription)")
                }
            }
        }

    }
    
    @objc func echo2(_ call: CAPPluginCall) {
        let value = call.getValue("value") ?? ""
        call.resolve(["value": implement.echo(value as! String)])
    }
    
    @objc func iOSSimPresent(_ call: CAPPluginCall){
        let telephonyInfo = CTTelephonyNetworkInfo()

        // Get the current radio access technology
        let radioAccess = telephonyInfo.serviceCurrentRadioAccessTechnology

        // Check if the value is available
        guard let data = radioAccess else {
            // Handle the case where data is nil
            print("Radio access technology is not available.")
            return
        }
        print("-- RADIO --");
        print(data);
        call.resolve(["value": data])
    }
}
