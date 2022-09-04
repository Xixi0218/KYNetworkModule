//
//  KYDataLoader.swift
//  KYNetworkModule
//
//  Created by keyon on 2022/9/4.
//

import Foundation

final class KYDataLoader: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    private var handlers = [URLSessionTask: KYTaskHandler]()

    var userSessionDelegate: URLSessionDelegate? {
        didSet {
            userTaskDelegate = userSessionDelegate as? URLSessionTaskDelegate
            userDataDelegate = userSessionDelegate as? URLSessionDataDelegate
            userDownloadDelegate = userSessionDelegate as? URLSessionDownloadDelegate
        }
    }

    private var userTaskDelegate: URLSessionTaskDelegate?
    private var userDataDelegate: URLSessionDataDelegate?
    private var userDownloadDelegate: URLSessionDownloadDelegate?

    private static let downloadDirectoryURL: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("com.github.keyon.get/Downloads/")
        try? FileManager.default.removeItem(at: url)
        return url
    }()

    func startDataTask(_ task: URLSessionDataTask, session: URLSession, delegate: URLSessionDataDelegate?) async throws -> KYResponse<Data> {
        try await withTaskCancellationHandler { task.cancel() } operation: {
            try await withUnsafeThrowingContinuation { continuation in
                session.delegateQueue.addOperation {
                    let handler = KYDataTaskHandler(delegate: delegate)
                    handler.completion = continuation.resume(with:)
                    self.handlers[task] = handler
                }
                task.resume()
            }
        }
    }

    func startDownloadTask(_ task: URLSessionDownloadTask, session: URLSession, delegate: URLSessionDownloadDelegate?) async throws -> KYResponse<URL> {
        try await withTaskCancellationHandler { task.cancel() } operation: {
            try await withUnsafeThrowingContinuation { continuation in
                session.delegateQueue.addOperation {
                    let handler = KYDownloadTaskHandler(delegate: delegate)
                    handler.completion = continuation.resume(with:)
                    self.handlers[task] = handler
                }
                task.resume()
            }
        }
    }

    func startUploadTask(_ task: URLSessionUploadTask, session: URLSession, delegate: URLSessionTaskDelegate?) async throws -> KYResponse<Data> {
        try await withTaskCancellationHandler { task.cancel() } operation: {
            try await withUnsafeThrowingContinuation { continuation in
                session.delegateQueue.addOperation {
                    let handler = KYDataTaskHandler(delegate: delegate)
                    handler.completion = continuation.resume(with:)
                    self.handlers[task] = handler
                }
                task.resume()
            }
        }
    }

    // MARK: URLSessionDelegate
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        userSessionDelegate?.urlSession?(session, didBecomeInvalidWithError: error)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        userSessionDelegate?.urlSessionDidFinishEvents?(forBackgroundURLSession: session)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let handler = handlers[task] else { return assertionFailure() }
        handlers[task] = nil
        handler.delegate?.urlSession?(session, task: task, didCompleteWithError: error)
        userTaskDelegate?.urlSession?(session, task: task, didCompleteWithError: error)

        switch handler {
        case let handler as KYDataTaskHandler:
            if let response = task.response, error == nil {
                let data = handler.data ?? Data()
                let response = KYResponse(value: data, data: data, response: response, task: task, metrics: handler.metrics)
                handler.completion?(.success(response))
            } else {
                handler.completion?(.failure(error ?? URLError(.unknown)))
            }
        case let handler as KYDownloadTaskHandler:
            if let location = handler.location, let response = task.response, error == nil {
                let response = KYResponse(value: location, data: Data(), response: response, task: task, metrics: handler.metrics)
                handler.completion?(.success(response))
            } else {
                handler.completion?(.failure(error ?? URLError(.unknown)))
            }
        default:
            break
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let handler = handlers[task]
        handler?.metrics = metrics
        handler?.delegate?.urlSession?(session, task: task, didFinishCollecting: metrics)
        userTaskDelegate?.urlSession?(session, task: task, didFinishCollecting: metrics)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        handlers[task]?.delegate?.urlSession?(session, task: task, willPerformHTTPRedirection: response, newRequest: request, completionHandler: completionHandler) ??
        userTaskDelegate?.urlSession?(session, task: task, willPerformHTTPRedirection: response, newRequest: request, completionHandler: completionHandler) ??
        completionHandler(request)
    }

    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        handlers[task]?.delegate?.urlSession?(session, taskIsWaitingForConnectivity: task)
        userTaskDelegate?.urlSession?(session, taskIsWaitingForConnectivity: task)
    }

#if swift(>=5.7)
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            handlers[task]?.delegate?.urlSession?(session, didCreateTask: task)
            userTaskDelegate?.urlSession?(session, didCreateTask: task)
        } else {
            // Doesn't exist on earlier versions
        }
    }
#endif

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        handlers[task]?.delegate?.urlSession?(session, task: task, didReceive: challenge, completionHandler: completionHandler) ??
        userTaskDelegate?.urlSession?(session, task: task, didReceive: challenge, completionHandler: completionHandler) ??
        completionHandler(.performDefaultHandling, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        handlers[task]?.delegate?.urlSession?(session, task: task, willBeginDelayedRequest: request, completionHandler: completionHandler) ??
        userTaskDelegate?.urlSession?(session, task: task, willBeginDelayedRequest: request, completionHandler: completionHandler) ??
        completionHandler(.continueLoading, nil)
    }

    // MARK: URLSessionDataDelegate
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        (handlers[dataTask] as? KYDataTaskHandler)?.dataDelegate?.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler) ??
        userDataDelegate?.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler) ??
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let handler = handlers[dataTask] as? KYDataTaskHandler else { return }
        handler.dataDelegate?.urlSession?(session, dataTask: dataTask, didReceive: data)
        userDataDelegate?.urlSession?(session, dataTask: dataTask, didReceive: data)
        if handler.data == nil {
            handler.data = Data()
        }
        handler.data!.append(data)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        userDataDelegate?.urlSession?(session, dataTask: dataTask, didBecome: downloadTask)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
        userDataDelegate?.urlSession?(session, dataTask: dataTask, didBecome: streamTask)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        (handlers[dataTask] as? KYDataTaskHandler)?.dataDelegate?.urlSession?(session, dataTask: dataTask, willCacheResponse: proposedResponse, completionHandler: completionHandler) ??
        userDataDelegate?.urlSession?(session, dataTask: dataTask, willCacheResponse: proposedResponse, completionHandler: completionHandler) ??
        completionHandler(proposedResponse)
    }

    // MARK: URLSessionDownloadDelegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let handler = (handlers[downloadTask] as? KYDownloadTaskHandler)
        let downloadsURL = KYDataLoader.downloadDirectoryURL
        try? FileManager.default.createDirectory(at: downloadsURL, withIntermediateDirectories: true, attributes: nil)
        let newLocation = downloadsURL.appendingPathExtension(location.lastPathComponent)
        try? FileManager.default.moveItem(at: location, to: newLocation)
        handler?.location = newLocation
        handler?.downloadDelegate?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: newLocation)
        userDownloadDelegate?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: newLocation)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        (handlers[downloadTask] as? KYDownloadTaskHandler)?.downloadDelegate?.urlSession?(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        userDownloadDelegate?.urlSession?(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        (handlers[downloadTask] as? KYDownloadTaskHandler)?.downloadDelegate?.urlSession?(session, downloadTask: downloadTask, didResumeAtOffset: fileOffset, expectedTotalBytes: expectedTotalBytes)
        userDownloadDelegate?.urlSession?(session, downloadTask: downloadTask, didResumeAtOffset: fileOffset, expectedTotalBytes: expectedTotalBytes)
    }
}


private class KYTaskHandler {
    let delegate: URLSessionTaskDelegate?
    var metrics: URLSessionTaskMetrics?

    init(delegate: URLSessionTaskDelegate?) {
        self.delegate = delegate
    }
}

private final class KYDataTaskHandler: KYTaskHandler {
    typealias Completion = (Result<KYResponse<Data>, Error>) -> Void

    let dataDelegate: URLSessionDataDelegate?
    var completion: Completion?
    var data: Data?

    override init(delegate: URLSessionTaskDelegate?) {
        self.dataDelegate = delegate as? URLSessionDataDelegate
        super.init(delegate: delegate)
    }
}

private final class KYDownloadTaskHandler: KYTaskHandler {
    typealias Completion = (Result<KYResponse<URL>, Error>) -> Void

    let downloadDelegate: URLSessionDownloadDelegate?
    var completion: Completion?
    var location: URL?

    init(delegate: URLSessionDownloadDelegate?) {
        self.downloadDelegate = delegate
        super.init(delegate: delegate)
    }
}

// MARK: Helpers

struct DataLoaderError: Error {
    let task: URLSessionTask
    let error: Error
}

struct AnyEncodable: Encodable {
    let value: Encodable

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

extension OperationQueue {
    static func serial() -> OperationQueue {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }
}

func encode(_ value: Encodable, using encoder: JSONEncoder) async throws -> Data? {
    if let data = value as? Data {
        return data
    } else if let string = value as? String {
        return string.data(using: .utf8)
    } else {
        return try await Task.detached {
            try encoder.encode(AnyEncodable(value: value))
        }.value
    }
}

func decode<T: Decodable>(_ data: Data, using decoder: JSONDecoder) async throws -> T {
    if T.self == Data.self {
        return data as! T
    } else if T.self == String.self {
        guard let string = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return string as! T
    } else {
        return try await Task.detached {
            try decoder.decode(T.self, from: data)
        }.value
    }
}
