//
//  APIClientDelegate.swift
//  Demo
//
//  Created by Keyon on 2023/2/1.
//

import Foundation
import KYNetworkModule

class APIClientDelegate: KYAPIClientDelegate {
    func client(_ client: KYAPIClient, willSendRequest request: inout URLRequest) async throws {
        debugPrint(request.url ?? "")
    }

    func client(_ client: KYAPIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        guard (200..<300).contains(response.statusCode) else {
            throw KYAPIError.unacceptableStatusCode(response.statusCode)
        }
    }
}
