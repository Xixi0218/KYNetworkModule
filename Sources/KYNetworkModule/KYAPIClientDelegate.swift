//
//  KYAPIClientDelegate.swift
//  KYNetworkModule
//
//  Created by keyon on 2022/9/4.
//

import Foundation

/// Allows you to modify ``KYAPIClient`` behavior.
public protocol KYAPIClientDelegate {
    /// 允许您在发送之前修改请求.
    ///
    /// 在每次发送接口之前调用
    ///
    /// - parameters:
    ///   - client: 发送请求的客户端.
    ///   - request: 即将发送的请求,可以修改
    func client(_ client: KYAPIClient, willSendRequest request: inout URLRequest) async throws

    /// 验证给定请求的响应.
    ///
    /// - parameters:
    ///   - client: 发送请求的客户端.
    ///   - response: 响应报文.
    ///   - data: 响应的正文,如果有.
    ///
    /// - throws: 如果响应码不在200到300之间会抛出错误``KYAPIError/unacceptableStatusCode(_:)``
    func client(_ client: KYAPIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws

    ///
    /// - parameters:
    ///   - client: 发送请求的客户端.
    ///   - task: 失败的任务.
    ///   - error: 遇到的错误.
    ///   - attempts: 已经执行的尝试次数.
    ///
    /// - returns: 如果返回`true`会重新去请求
    func client(_ client: KYAPIClient, shouldRetry task: URLSessionTask, error: Error, attempts: Int) async throws -> Bool

}

public extension KYAPIClientDelegate {
    func client(_ client: KYAPIClient, willSendRequest request: inout URLRequest) async throws {
        // Do nothing
    }

    func client(_ client: KYAPIClient, shouldRetry task: URLSessionTask, error: Error, attempts: Int) async throws -> Bool {
        false // Disabled by default
    }

    func client(_ client: KYAPIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        guard (200..<300).contains(response.statusCode) else {
            throw KYAPIError.unacceptableStatusCode(response.statusCode)
        }
    }
}

struct KYDefaultAPIClientDelegate: KYAPIClientDelegate {}
