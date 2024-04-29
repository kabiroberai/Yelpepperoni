import Foundation
import CryptoKit
import StoreKit

func hook() {
    var swizzled: Set<ObjectIdentifier> = []

    let sel = NSSelectorFromString("productServiceWithErrorHandler:")
    let m = class_getInstanceMethod(NSClassFromString("SKServiceBroker"), sel)!
    var orig: IMP?
    orig = method_setImplementation(m, imp_implementationWithBlock({ obj, del in
        let orig = unsafeBitCast(orig, to: (@convention (c) (AnyObject, Selector, AnyObject?) -> AnyObject).self)
        let ret = orig(obj, sel, del)
        guard swizzled.insert(ObjectIdentifier(type(of: ret))).inserted else { return ret }

        let sel2 = NSSelectorFromString("enumerateCurrentReceiptsForProductID:withReceiver:reply:")
        let m2 = class_getInstanceMethod(type(of: ret), sel2)!
        var orig2: IMP?
        orig2 = method_setImplementation(m2, imp_implementationWithBlock({
            service, request, receiver, reply in
            let orig2 = unsafeBitCast(orig2, to: (@convention(c) (AnyObject, Selector, AnyObject, AnyObject, AnyObject?) -> Void).self)
            defer { orig2(service, sel2, request, receiver, reply) }
            guard swizzled.insert(ObjectIdentifier(type(of: receiver))).inserted else { return }

            let sel3 = NSSelectorFromString("receivedTransactions:")
            let m3 = class_getInstanceMethod(type(of: receiver), sel3)!
            var orig3: IMP?
            orig3 = method_setImplementation(m3, imp_implementationWithBlock({ receiver, resp in
                let orig3 = unsafeBitCast(orig3, to: (@convention(c) (AnyObject, Selector, AnyObject?) -> Void).self)

                let crt = """
                MIIBzDCCAXOgAwIBAgIUEayhVFhKOhJW0U5Fyj2jkd9SOoIwCgYIKoZIzj0EAwIwVTESMBAGA1UEAwwJRmFrZSBDZXJ0MQswCQYDVQQGEwJVUzENMAsGA1UELhMEc29tZTEjMCEGA1UdDwwaY3JpdGljYWwsIGRpZ2l0YWxTaWduYXR1cmUwHhcNMjQwNDI5MDIyNTAzWhcNMzQwMTI5MDIyNTAzWjBVMRIwEAYDVQQDDAlGYWtlIENlcnQxCzAJBgNVBAYTAlVTMQ0wCwYDVQQuEwRzb21lMSMwIQYDVR0PDBpjcml0aWNhbCwgZGlnaXRhbFNpZ25hdHVyZTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABFRumjh18XzeGdHvWNhu2IE4tpimzorS2PZOHQm4RnGENtuAJnymkai109eZxE+adEcOF4pLSRzkRIHzFAMAy3GjITAfMB0GA1UdDgQWBBQCO6kGM9IXweWNfrDAfzTAPkL+LjAKBggqhkjOPQQDAgNHADBEAiB/yavSnChYfwSxbvD4z5uzjtgnms6UmEoldS/PwrwAcgIgJQq5YmGpUsKZPcnxL1+xWBdJPNCmifnGEIpLP9YC2ME=
                """
                let key = try! P256.Signing.PrivateKey(pemRepresentation: """
                -----BEGIN EC PRIVATE KEY-----
                MHcCAQEEIHGhoQ31PWT9boiqGMenek1TZN/imBsYf0isu6vCOUoBoAoGCCqGSM49
                AwEHoUQDQgAEVG6aOHXxfN4Z0e9Y2G7YgTi2mKbOitLY9k4dCbhGcYQ224AmfKaR
                qLXT15nET5p0Rw4XiktJHOREgfMUAwDLcQ==
                -----END EC PRIVATE KEY-----
                """)

                let header = #"{"alg":"ES256","typ":"JWT","x5c":["\#(crt)"]}"#
                let headerB64 = Data(header.utf8).base64URLEncodedString()

                let device = AppStore.deviceVerificationID!.uuidString.lowercased()
                let nonce = UUID().uuidString.lowercased()
                let verification = Data(SHA384.hash(data: Data((nonce + device).utf8))).base64EncodedString()

                let payload = """
                {
                  "originalPurchaseDate": 1714353790654,
                  "signedDate": 1714353791612,
                  "transactionId": "0",
                  "quantity": 1,
                  "purchaseDate": 1714353790654,
                  "environment": "Xcode",
                  "price": 4990,
                  "inAppOwnershipType": "PURCHASED",
                  "deviceVerification": "\(verification)",
                  "transactionReason": "PURCHASE",
                  "storefront": "USA",
                  "currency": "USD",
                  "type": "Non-Consumable",
                  "originalTransactionId": "0",
                  "deviceVerificationNonce": "\(nonce)",
                  "bundleId": "com.kabiroberai.Yelpepperoni",
                  "storefrontId": "143441",
                  "productId": "com.kabiroberai.Yelpepperoni.pro"
                }
                """
                let payloadB64 = Data(payload.utf8).base64URLEncodedString()

                let hash = SHA256.hash(data: Data("\(headerB64).\(payloadB64)".utf8))
                let signature = try! key.signature(for: hash).withUnsafeBytes { Data($0) }
                let signatureB64 = signature.base64URLEncodedString()

                let receipt = "\(headerB64).\(payloadB64).\(signatureB64)"
                orig3(receiver, sel3, [receipt] as AnyObject)
            } as @convention(block) (AnyObject, AnyObject?) -> Void))
        } as (@convention(block) (AnyObject, AnyObject, AnyObject, AnyObject) -> Void)))

        let sel4 = NSSelectorFromString("productsWithRequest:responseReceiver:reply:")
        let m4 = class_getInstanceMethod(type(of: ret), sel4)!
        var orig4: IMP?
        orig4 = method_setImplementation(m4, imp_implementationWithBlock({
            service, request, receiver, reply in
            let orig4 = unsafeBitCast(orig4, to: (@convention(c) (AnyObject, Selector, AnyObject, AnyObject, AnyObject?) -> Void).self)
            defer { orig4(service, sel4, request, receiver, reply) }
            guard swizzled.insert(ObjectIdentifier(type(of: receiver))).inserted else { return }

            let sel5 = NSSelectorFromString("receivedResponse:")
            let m5 = class_getInstanceMethod(type(of: receiver), sel5)!
            var orig5: IMP?
            orig5 = method_setImplementation(m5, imp_implementationWithBlock({ receiver, resp in
                let orig5 = unsafeBitCast(orig5, to: (@convention(c) (AnyObject, Selector, AnyObject?) -> Void).self)
                guard let data = resp as? Data,
                      var plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                    return orig5(receiver, sel5, resp)
                }
                plist["products"] = Data("""
                [{"type":"in-apps","id":"BAC98A2F","attributes":{"offerName":"com.kabiroberai.Yelpepperoni.pro","isFamilyShareable":false,"offers":[{"price":"4.99","currencyCode":"USD","priceFormatted":"$4.99"}],"icuLocale":"en_US@currency=USD","kind":"Non-Consumable","description":{"standard":"Unlock amazing discounts!"},"artwork":{"width":1024,"url":"","height":1024},"name":"YelpeppePROni"},"href":"/v1/catalog/usa/in-apps/BAC98A2F"}]
                """.utf8)
                let encoded = try! PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
                orig5(receiver, sel5, encoded as NSData)
            } as @convention(block) (AnyObject, AnyObject?) -> Void))
        } as (@convention(block) (AnyObject, AnyObject, AnyObject, AnyObject) -> Void)))

        return ret
    } as @convention(block) (AnyObject, AnyObject?) -> AnyObject?))
}

extension Data {
    func base64URLEncodedString() -> String {
        var str = base64EncodedString()
        str = str.replacingOccurrences(of: "+", with: "-")
        str = str.replacingOccurrences(of: "/", with: "_")
        str = str.replacingOccurrences(of: "=", with: "")
        return str
    }
}
