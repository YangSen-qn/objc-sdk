//
//  ViewController.swift
//  QiniuDemoSwift
//
//  Created by yangsen on 2025/9/22.
//

import UIKit

import Photos
import QiniuSDK
import ZLPhotoBrowser

class ViewController: UIViewController {

    var asset : PHAsset? = nil
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func upload(_ sender: UIButton) {
        let token = ""
        let uploader = QNUploadManager(configuration: nil)
        let option = QNUploadOption.init(mime: "zip", progressHandler: { key, progress in
            print("key:\(String(describing: key)) progress:\(progress)")
        }, params: nil, checkCrc: false, cancellationSignal: nil);
        
        if asset != nil {
            uploader?.put(asset, key: "iOS-demo-test", token: token, complete: { (response, key, responseData) in
                if response?.isOK == true {
                    print("upload success:\(String(describing: responseData))")
                } else {
                    print("upload fail:\(String(describing: response))")
                }
            }, option: option)
        } else {
            let filePath = Bundle.main.path(forResource: "image.jpg", ofType: nil)
            uploader?.putFile(filePath, key: "iOS-demo-test-a", token: token, complete: { (response, key, responseData) in
                if response?.isOK == true {
                    print("upload success:\(String(describing: responseData))")
                } else {
                    print("upload fail:\(String(describing: response))")
                }
            }, option: option)
        }

//        let r = PHAssetResource.assetResources(for: self.asset!)
//        let file = try? QNPHAssetResource(r.first)
//        print("\(String(describing: file?.description))")
    }
    
    @IBAction func selectImage(_ sender: Any) {
        
        let picker = ZLPhotoPicker()
        picker.selectImageBlock = { [weak self] results, isOriginal in
            // your code
            if results.count > 0 {
                self?.asset = results[0].asset
                self?.imageView.image = results[0].image
            }
        }
        picker.showPreview(animate: true, sender: self)
    }
}

