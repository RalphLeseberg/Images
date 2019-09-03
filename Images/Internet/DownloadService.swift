//
//  DownloadService.swift
//  Images
//
//  Created by r leseberg on 9/3/19.
//  Copyright © 2019 starion. All rights reserved.
//

import Foundation
import SystemConfiguration

/// Download Request error type
public enum DownloadRequestErrorType: Error {
    /// Download Canceled
    case cancel
    /// URL not found
    case notFound
    /// not connect to the internet
    case notConnected
    /// a base error
    case other(str: String)
    
    public var localizedDescription: String {
        switch self {
        case .cancel: return "Download canceled"
        case .notFound: return "URL not found"
        case .notConnected: return "Not connected to the internet"
        case .other(let str): return str
        }
    }
}

typealias DownloadRequestkCompletion = (_ data: Data) -> Void
typealias DownloadRequestFailureCompletion = (_ error: DownloadRequestErrorType) -> Void

class DownloadService: NSObject {
    
    let maxHTTPLength = 10000
    
    private var session: URLSession!
    private var myData: Data?
    
    private var dataDownloadTasks = [DataDownloadTask]()
    
    public static let shared = DownloadService()
    
    private override init() {
        super.init()
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.Starion.background")
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil )
    }
    
    func download(request: URLRequest,
                  success: @escaping DownloadRequestkCompletion,
                  failure: @escaping DownloadRequestFailureCompletion) {
        if isConnectedToNetwork() {
            myData = Data()
            let task = session.dataTask(with: request)
            let downloadTask = DataDownloadTask(task: task, success: success, failure: failure)
            dataDownloadTasks.append(downloadTask)
            
            print("DownloadService download task count: \(dataDownloadTasks.count))")
            downloadTask.resume()
        } else {
            print("DownloadService download: not connected to the internet")
            failure(DownloadRequestErrorType.notConnected)
        }
    }
    
    func cancelDownloads() {
        dataDownloadTasks.reversed().forEach { $0.cancel() }
        print("DownloadService cancelDownloads task count: \(dataDownloadTasks.count))")
    }
}

extension DownloadService: URLSessionDownloadDelegate, URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        guard let task = dataDownloadTasks.first(where: { $0.task == dataTask }) else {
            return
        }
        
        task.expectedSize = Int(response.expectedContentLength)
        print("urlSession expected size: \(response.expectedContentLength) ")
        let response = response as? HTTPURLResponse
        if response?.statusCode != 200 {
            print("urlSession expected code:  \(String(describing: response?.statusCode))")
            task.failure(DownloadRequestErrorType.notFound)
            completionHandler(.cancel)
        } else {
            completionHandler(.allow)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let task = dataDownloadTasks.first(where: { $0.task == dataTask }) else {
            return
        }
        
        print("DownloadService didReceive size: \(data.count)")
        task.data.append(data)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("DownloadService didFinishDownloadingTo")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let index = dataDownloadTasks.index(where: { $0.task == task }) else {
            return
        }
        let task = dataDownloadTasks.remove(at: index)
        print("DownloadService didComplete task count: \(dataDownloadTasks.count))")
        
        if let e = error {
            print("InternetTest didCompleteWithError error: \(e.localizedDescription)")
            task.failure(DownloadRequestErrorType.other(str: e.localizedDescription))
        } else {
            print("DownloadService didComplete data received size: \(task.data.count))")
            task.success()
        }
    }
}

// from https://stackoverflow.com/questions/30743408/check-for-internet-connection-with-swift
extension DownloadService {
    func isConnectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }
        
        // Working for Cellular and WIFI
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let ret = (isReachable && !needsConnection)
        
        return ret
    }
}

private class DataDownloadTask {
    
    private(set) var task: URLSessionDataTask
    fileprivate let successCB: DownloadRequestkCompletion
    fileprivate let failureCB: DownloadRequestFailureCompletion
    
    var expectedSize = 0
    var data = Data()
    
    init(task: URLSessionDataTask,
         success: @escaping DownloadRequestkCompletion,
         failure: @escaping DownloadRequestFailureCompletion) {
        self.task = task
        self.successCB = success
        self.failureCB = failure
    }
    
    deinit {
        print("Deinit")
    }
    
    func resume() {
        task.resume()
    }
    
    func suspend() {
        task.suspend()
    }
    
    func cancel() {
        task.cancel()
    }
    
    func success() {
        print("success")
        successCB(data)
    }
    
    func failure(_ error: DownloadRequestErrorType) {
        print("failure")
        failureCB(error)
    }
}
