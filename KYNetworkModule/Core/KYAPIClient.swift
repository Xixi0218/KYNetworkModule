//
//  KYAPIClient.swift
//  KYNetworkModule
//
//  Created by keyon on 2022/9/4.
//

import Foundation

public actor KYAPIClient {
    /// 初始化APIClient配置
    public nonisolated let configuration: Configuration
    public nonisolated let session: URLSession

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let delegate: KYAPIClientDelegate
    private let dataLoader = KYDataLoader()


    /// ``KYAPIClient``的配置化模型.
    public struct Configuration: @unchecked Sendable {
        /// base URL. 比如, `"https://api.github.com"`.
        public var baseURL: URL?
        /// APIClient的代理对象
        public var delegate: KYAPIClientDelegate?
        /// URLSessionConfiguration的配置, 默认是`URLSessionConfiguration.default`.
        public var sessionConfiguration: URLSessionConfiguration = .default
        /// 监听底层的URLSession的代理
        public var sessionDelegate: URLSessionDelegate?
        /// session的线程,默认是`OperationQueue.serial()`
        public var sessionDelegateQueue: OperationQueue?
        /// 默认使用 `.iso8601` 解码策略.
        public var decoder: JSONDecoder
        /// 默认使用 `.iso8601` 编码策略.
        public var encoder: JSONEncoder

        /// 配置化模型的初始化.
        public init(
            baseURL: URL?,
            sessionConfiguration: URLSessionConfiguration = .default,
            delegate: KYAPIClientDelegate? = nil
        ) {
            self.baseURL = baseURL
            self.sessionConfiguration = sessionConfiguration
            self.delegate = delegate
            self.decoder = JSONDecoder()
            self.decoder.dateDecodingStrategy = .iso8601
            self.encoder = JSONEncoder()
            self.encoder.dateEncodingStrategy = .iso8601
        }
    }

    // MARK: Initializers

    /// 使用给定的配置初始化客户端
    public init(configuration: Configuration) {
        self.configuration = configuration
        let delegateQueue = configuration.sessionDelegateQueue ?? .serial()
        self.session = URLSession(configuration: configuration.sessionConfiguration, delegate: dataLoader, delegateQueue: delegateQueue)
        self.dataLoader.userSessionDelegate = configuration.sessionDelegate
        self.delegate = configuration.delegate ?? KYDefaultAPIClientDelegate()
        self.decoder = configuration.decoder
        self.encoder = configuration.encoder
    }

    // MARK: Sending Requests

    /// 发送给定的请求并返回解码的响应.
    ///
    /// - parameters:
    ///   - request: 执行的请求.
    ///   - delegate: 特定于任务的代理.
    ///
    /// - returns: 具有解码的响应.
    @discardableResult public func send<T: Decodable>(
        _ request: KYRequest<T>,
        delegate: URLSessionDataDelegate? = nil
    ) async throws -> KYResponse<T> {
        let response = try await data(for: request, delegate: delegate)
        let value: T = try await decode(response.data, using: decoder)
        return response.map { _ in value }
    }

    /// 发送给定的请求.
    ///
    /// - parameters:
    ///   - request: 执行的请求.
    ///   - delegate: 特定于任务的代理.
    ///
    /// - returns: 具有空值的响应.
    @discardableResult public func send(
        _ request: KYRequest<Void>,
        delegate: URLSessionDataDelegate? = nil
    ) async throws -> KYResponse<Void> {
        try await data(for: request, delegate: delegate).map { _ in () }
    }

    // MARK: Fetching Data

    /// 获取给定请求的数据.
    ///
    /// - parameters:
    ///   - request: 执行的请求.
    ///   - delegate: 特定于任务的代理.
    ///
    /// - returns: 具有原始响应数据的响应.
    public func data<T>(
        for request: KYRequest<T>,
        delegate: URLSessionDataDelegate? = nil
    ) async throws -> KYResponse<Data> {
        let request = try await makeURLRequest(for: request)
        return try await performWithRetries {
            var request = request
            try await self.delegate.client(self, willSendRequest: &request)
            let task = session.dataTask(with: request)
            do {
                let response = try await dataLoader.startDataTask(task, session: session, delegate: delegate)
                try validate(response)
                return response
            } catch {
                throw DataLoaderError(task: task, error: error)
            }
        }
    }

    // MARK: Downloads

    /// 将请求的数据下载到文件中.
    ///
    /// - parameters:
    ///   - request: 提供 URL 和其他参数的请求对象.
    ///   - delegate: 特定于任务的代理.
    ///
    /// - returns: 带有下载文件位置的响应。
    /// 文件在应用重新启动之前不会自动删除。
    /// 确保将文件移动到应用程序中的已知位置。
    public func download<T>(
        for request: KYRequest<T>,
        delegate: URLSessionDownloadDelegate? = nil
    ) async throws -> KYResponse<URL> {
        var urlRequest = try await makeURLRequest(for: request)
        try await self.delegate.client(self, willSendRequest: &urlRequest)
        let task = session.downloadTask(with: urlRequest)
        return try await _startDownloadTask(task, delegate: delegate)
    }

    /// 从给定的恢复数据恢复下载.
    ///
    /// - parameters:
    ///   - delegate: 特定于任务的代理.
    public func download(
        resumeFrom resumeData: Data,
        delegate: URLSessionDownloadDelegate? = nil
    ) async throws -> KYResponse<URL> {
        let task = session.downloadTask(withResumeData: resumeData)
        return try await _startDownloadTask(task, delegate: delegate)
    }

    private func _startDownloadTask(
        _ task: URLSessionDownloadTask,
        delegate: URLSessionDownloadDelegate?
    ) async throws -> KYResponse<URL> {
        let response = try await dataLoader.startDownloadTask(task, session: session, delegate: delegate)
        try validate(response)
        return response
    }

    // MARK: Upload

    /// 从文件上传数据的便捷方法.
    ///
    /// - parameters:
    ///   - request: 上传数据的 URLRequest.
    ///   - fileURL: 要上传的文件.
    ///   - delegate: 特定于任务的代理.
    ///
    /// Returns 解码的响应.
    @discardableResult public func upload<T: Decodable>(
        for request: KYRequest<T>,
        fromFile fileURL: URL,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> KYResponse<T> {
        let response = try await _upload(for: request, fromFile: fileURL, delegate: delegate)
        let value: T = try await decode(response.data, using: decoder)
        return response.map { _ in value }
    }

    /// 从文件上传数据的便捷方法.
    ///
    /// - parameters:
    ///   - request: 上传数据的 URLRequest.
    ///   - fileURL: 要上传的文件.
    ///   - delegate: 特定于任务的代理.
    ///
    /// Returns 解码的响应.
    @discardableResult public func upload(
        for request: KYRequest<Void>,
        fromFile fileURL: URL,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> KYResponse<Void> {
        try await _upload(for: request, fromFile: fileURL, delegate: delegate).map { _ in () }
    }

    private func _upload<T>(
        for request: KYRequest<T>,
        fromFile fileURL: URL,
        delegate: URLSessionTaskDelegate?
    ) async throws -> KYResponse<Data> {
        let request = try await makeURLRequest(for: request)
        return try await performWithRetries {
            var request = request
            try await self.delegate.client(self, willSendRequest: &request)
            let task = session.uploadTask(with: request, fromFile: fileURL)
            do {
                let response = try await dataLoader.startUploadTask(task, session: session, delegate: delegate)
                try validate(response)
                return response
            } catch {
                throw DataLoaderError(task: task, error: error)
            }
        }
    }

    // MARK: Making Requests

    /// 为给定的请求创建 `URLRequest`.
    private func makeURLRequest<T>(
        for request: KYRequest<T>
    ) async throws -> URLRequest {
        let url = try makeURL(url: request.url, query: request.query)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = request.headers
        urlRequest.httpMethod = request.method.string
        if let body = request.body {
            urlRequest.httpBody = try await encode(body, using: encoder)
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil &&
                session.configuration.httpAdditionalHeaders?["Content-Type"] == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        if urlRequest.value(forHTTPHeaderField: "Accept") == nil &&
            session.configuration.httpAdditionalHeaders?["Accept"] == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        return urlRequest
    }

    private func makeURL(url: String, query: [(String, String?)]?) throws -> URL {
        func makeURL(path: String) -> URL? {
            guard !path.isEmpty else {
                return configuration.baseURL?.appendingPathComponent("/")
            }
            guard let url = URL(string: path) else {
                return nil
            }
            return url.scheme == nil ? configuration.baseURL?.appendingPathComponent(path) : url
        }
        guard let url = makeURL(path: url), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        if let query = query, !query.isEmpty {
            components.queryItems = query.map(URLQueryItem.init)
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    // MARK: Helpers

    private func performWithRetries<T>(
        attempts: Int = 1,
        send: () async throws -> T
    ) async throws -> T {
        do {
            return try await send()
        } catch {
            guard let error = error as? DataLoaderError else {
                throw error
            }
            guard try await delegate.client(self, shouldRetry: error.task, error: error.error, attempts: attempts) else {
                throw error.error
            }
            return try await performWithRetries(attempts: attempts + 1, send: send)
        }
    }

    private func validate<T>(_ response: KYResponse<T>) throws {
        guard let httpResponse = response.response as? HTTPURLResponse else { return }
        try delegate.client(self, validateResponse: httpResponse, data: response.data, task: response.task)
    }
}

/// 表示客户端遇到的错误.
public enum KYAPIError: Error, LocalizedError, CustomStringConvertible {
    case unacceptableStatusCode(Int)

    /// 返回调试描述.
    public var errorDescription: String? {
        switch self {
        case .unacceptableStatusCode(let statusCode):
            return "Response status code was unacceptable: \(statusCode)."
        }
    }

    public var description: String {
        return errorDescription ?? ""
    }
}
