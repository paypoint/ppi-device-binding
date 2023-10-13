import Foundation
import Capacitor
import MessageUI

@objc(DeviceBindingPlugin)
public class DeviceBindingPlugin: CAPPlugin, MFMessageComposeViewControllerDelegate {
    
    private let implement = DeviceBinding()
    private var autoCancelTimer: Timer? // Instance variable to store the timer

    
    @objc func echo(_ call: CAPPluginCall){
        let value = call.getValue("value") ?? ""
        call.resolve(["value":implement.echo(value as! String) ])
    }
    
    // This method is called when the 'echo' function is invoked from JavaScript
    @objc func iOSComposeSMS(_ call: CAPPluginCall) {
        // Retrieve message body from the function call, or set a default value
        guard let messageBody = call.getString("messageContent") else {
            call.reject("INVALID_BODY", "Message body is missing")
            return
        }
        
        // Retrieve recipient phone number from the function call, or set a default value
        let recipient = call.getString("destinationNumber") ?? "8655874341" // Default phone number
        
        // Check if the device can send text messages
        if MFMessageComposeViewController.canSendText() {
            // Execute code on the main queue asynchronously
            DispatchQueue.main.async {
                // Create a message composer view controller and set its properties
                let composeVC = MFMessageComposeViewController()
                composeVC.body = messageBody
                composeVC.recipients = [recipient]
                composeVC.messageComposeDelegate = self
                
                // Get the root view controller and present the message composer
                if let rootViewController = self.bridge?.viewController {
                    rootViewController.present(composeVC, animated: true, completion: nil)
                    
                    // Schedule a timer to dismiss the message composer after 5 seconds of inactivity
                    self.autoCancelTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
                        composeVC.dismiss(animated: false) {
                            // Send the SMS compose result event with 'cancelled' status
                            self?.sendSMSResultEvent(status: .cancelled)
                        }
                        // Invalidate the timer after dismissing the composer
                        self?.autoCancelTimer?.invalidate()
                        self?.autoCancelTimer = nil
                    }
                }
                
                // Resolve the function call with a success status
                call.resolve(["status": "success"])
            }
        } else {
            // Reject the function call with an error if SMS is not supported on the device
            call.reject("SMS_NOT_SUPPORTED", "SMS is not supported on this device")
        }
    }
    
    // Helper method to send the SMS compose result event to JavaScript
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
        
        // Construct the JavaScript event and dispatch it to the web view
        let jsEvent = "window.dispatchEvent(new CustomEvent('onSMSComposeResult', { detail: { status: '\(statusString)' } }));"
        self.bridge?.webView?.evaluateJavaScript(jsEvent, completionHandler: nil)
    }
    
    // Delegate method called when the message composer finishes composing
    public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        // Dismiss the message composer
        controller.dismiss(animated: true, completion: nil)
        
        // Send the SMS compose result event with the appropriate status
        sendSMSResultEvent(status: result)
    }
}
