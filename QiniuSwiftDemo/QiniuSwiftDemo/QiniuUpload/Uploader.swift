//
//  Uploader.swift
//  QiniuSwiftDemo
//
//  Created by yangsen on 2024/6/14.
//

import Foundation
import UIKit
import QiniuSDK

typealias UploadCancel = () -> Bool
typealias UploadProgressHander = (_ send: Int64, _ total: Int64) -> Void
typealias UploadCompleteHander = (_ response: QNResponseInfo?, _ responseData: [AnyHashable : Any]?) -> Void

struct Uploader {
    
    static private var token = "dxVQk8gyk3WswArbNhdKIwmwibJ9nFsQhMNUmtIM:rJFJ8gG4elgOwiaDva00sGathQc=:eyJzY29wZSI6InRlc3QteXMiLCJkZWFkbGluZSI6MzQzNjcxODQ4NX0="
    static private var uploadManager = QNUploadManager()

    // 注意：此处和上传操作有并发问题
    static func updateUploadConfig(config: QNConfiguration) {
        uploadManager = QNUploadManager(configuration: config)
    }

    
    /// 上传
    ///
    /// - Parameters:
    ///   - image: 上传的图片
    ///   - key: 图片保存 Key
    ///   - progress: 上传进度回调
    ///   - cancel: 取消回调，取消不能主动取消，SDK 内部在合适的时机会调用此函数，如果此函数返回为 true，则 SDK 内部上传 结束
    ///   - complete: 完成回调
    static func uploadImage(image: UIImage,
                            key: String,
                            mimeType: String = "",
                            progress: UploadProgressHander? = nil,
                            cancel: UploadCancel? = nil,
                            complete: @escaping UploadCompleteHander) {
        
        updateTokenIfNeeded()
        
        let uploadOptions = QNUploadOption(mime: mimeType,
                                           byteProgressHandler: { key, send, total in
            progress?(send, total)
        },
                                           params: [AnyHashable : Any](),
                                           checkCrc: true,
                                           cancellationSignal: cancel)
        
        // 上传
        uploadManager?.put(image.pngData(),
                           key: key,
                           token: token,
                           complete: { reponse, key, responseData in
            complete(reponse, responseData)
        }, option: uploadOptions)
        
    }
    
    // 给 token 预留充分的时间，需要保证在文件上传结束之前 token 一直有效，比如：5min, 大文件可能需要更长，
    // 在下发 token 时也给出有效的时间戳
    static func updateTokenIfNeeded() {
        
    }
}

