//
//  JYAPIClientDelegate.swift
//  KYNetworkModule
//
//  Created by keyon on 2022/9/4.
//

import Foundation

class JYAPIClientDelegate: KYAPIClientDelegate {
    func client(_ client: KYAPIClient, willSendRequest request: inout URLRequest) async throws {
        debugPrint(request.url ?? "")
    }

    func client(_ client: KYAPIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        guard (200..<300).contains(response.statusCode) else {
            throw KYAPIError.unacceptableStatusCode(response.statusCode)
        }
//        let string = String(data: data, encoding: .utf8)
//        debugPrint(string ?? "")
    }
}
