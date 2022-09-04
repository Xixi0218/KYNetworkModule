//
//  KYRequest.swift
//  KYNetworkModule
//
//  Created by keyon on 2022/9/4.
//

import Foundation

public enum KYHTTPMethod {
    case get
    case post
    case put
    case patch
    case delete
    case options
    case head
    case trace

    var string: String {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
        case .put:
            return "PUT"
        case .patch:
            return "PATCH"
        case .delete:
            return "DELETE"
        case .options:
            return "OPTIONS"
        case .head:
            return "HEAD"
        case .trace:
            return "TRACE"
        }
    }
}

public class KYRequest<Response>: @unchecked Sendable {
    /// HTTP 方法，默认是get.
    public var method: KYHTTPMethod
    /// Resource URL. 可以是绝对的或相对的.
    public let url: String
    /// Request query items.
    public var query: [(String, String?)]?
    /// Request body.
    public let body: Encodable?
    /// 添加到请求中的请求头.
    public var headers: [String: String]?

    /// 使用给定的参数和请求正文初始化`KYRequest`.
    public init(
        method: KYHTTPMethod = .get,
        url: String,
        query: [(String, String?)]? = nil,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) {
        self.method = method
        self.url = url
        self.query = query
        self.headers = headers
        self.body = body
    }

    /// Changes the respones type keeping the rest of the request parameters.
    public func withResponse<T>(_ type: T.Type) -> KYRequest<T> {
        KYRequest<T>(method: method, url: url, query: query, body: body, headers: headers)
    }
}
