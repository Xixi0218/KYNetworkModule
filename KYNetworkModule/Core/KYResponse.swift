//
//  KYResponse.swift
//  JYNetworkModule
//
//  Created by keyon on 2022/9/3.
//

import Foundation

public class KYResponse<T>{
    /// 解码响应值.
    public let value: T
    /// 原始响应.
    public let response: URLResponse
    /// 响应的HTTP状态码.
    public var statusCode: Int? { (response as? HTTPURLResponse)?.statusCode }
    /// 原始的响应数据.
    public let data: Data
    /// 原始请求.
    public var originalRequest: URLRequest? { task.originalRequest }
    /// 任务当前正在处理的URL请求对象。可能与原始请求不同.
    public var currentRequest: URLRequest? { task.currentRequest }
    /// 已完成任务.
    public let task: URLSessionTask
    /// 为请求收集的任务指标.
    public let metrics: URLSessionTaskMetrics?

    /// 响应的初始化.
    public init(value: T, data: Data, response: URLResponse, task: URLSessionTask, metrics: URLSessionTaskMetrics? = nil) {
        self.value = value
        self.data = data
        self.response = response
        self.task = task
        self.metrics = metrics
    }

    /// 返回包含映射值的响应.
    public func map<U>(_ closure: (T) throws -> U) rethrows -> KYResponse<U> {
        KYResponse<U>(value: try closure(value), data: data, response: response, task: task, metrics: metrics)
    }
}

extension KYResponse where T == URL {
    public var location: URL { value }
}

extension KYResponse: @unchecked Sendable where T: Sendable {}
