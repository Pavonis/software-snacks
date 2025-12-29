import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let profile: UUID?
        if #available(iOS 17.0, macOS 14.0, *) {
            profile = request?.userInfo?[SFExtensionProfileKey] as? UUID
        } else {
            profile = request?.userInfo?["profile"] as? UUID
        }

        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        os_log(.default, "FIL(L)M: Received message from browser.runtime.sendNativeMessage: %@", String(describing: message))

        let response = NSExtensionItem()
        response.userInfo = [ SFExtensionMessageKey: [ "status": "received" ] ]

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
