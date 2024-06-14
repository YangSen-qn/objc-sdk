//
//  ContentView.swift
//  QiniuSwiftDemo
//
//  Created by yangsen on 2024/6/13.
//

import PopupView
import SwiftUI

private let kUploadBtnTextUpload = "上传"
private let kUploadBtnTextUploading = "上传..."

struct ContentView: View {

	@State private var key = "iOS-Swift-Demo.png"
	@State private var mimeType = ""
	@State private var imagePickerSourceType = UIImagePickerController.SourceType.photoLibrary
	@State private var showToast = false
	@State private var toastText = ""
	@State private var showAlert = false
	@State private var showImagePicker = false
	@State private var selectedImage: UIImage = UIImage(resource: ImageResource(name: "placeholder.png", bundle: .main))
	@State private var btnTitle: String = kUploadBtnTextUpload
	@State private var processValue: CGFloat = 0
    @State private var isCancel = false

	var body: some View {
		NavigationView {
			VStack {
                HStack {
                    Text("Key:")
                    TextField("请输入文件保存的 Key（必需）", text: $key)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("MimeType:")
                    TextField("文件的 MimeType（可选）", text: $mimeType)
                        .foregroundColor(.gray)
                }
				
				Image(uiImage: selectedImage)
					.resizable()
					.scaledToFit()
					.frame(minWidth: nil, idealWidth: nil, maxWidth: 0.8 * kScreenW,
					minHeight: nil, idealHeight: nil, maxHeight: 0.4 * kScreenH,
					alignment: .center)
					.background(kBgColor)
					.cornerRadius(3.0)
				ProgressView(value: processValue * 0.01)
					.frame(minWidth: nil, idealWidth: nil, maxWidth: 0.8 * kScreenW,
					minHeight: nil, idealHeight: nil, maxHeight: 3,
					alignment: .center)
					.progressViewStyle(LinearProgressViewStyle(tint: kMainColor))
				Spacer().frame(width: 10, height: 30, alignment: .center)
                Button(btnTitle, action: upload)
					.frame(width: 0.8 * kScreenW, height: 0.05 * kScreenH)
					.background(kMainColor)
					.foregroundColor(.white)
					.cornerRadius(5)
					.padding()
                Button("取消", action: cancel)
                    .frame(width: 0.8 * kScreenW, height: 0.05 * kScreenH)
                    .background(kMainColor)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    .padding()
			}.toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingView()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
				ToolbarItemGroup(placement: .navigationBarTrailing) {
					Button(action: {
						showAlert = true
					}) {
						Image(systemName: "photo")
					}
				}
			}.alert("图片来源", isPresented: $showAlert, actions: {
				VStack {
					Button("相机") {
						showAlert = false
						imagePickerSourceType = .camera
						showImagePicker = true
					}
						.background(Color.white)
						.foregroundColor(.purple)
					Button("相册") {
						showAlert = false
						imagePickerSourceType = .photoLibrary
						showImagePicker = true
					}
						.background(Color.white)
						.foregroundColor(.purple)
					Button("取消") { }
						.background(Color.white)
						.foregroundColor(.purple)
				}.foregroundColor(kMainColor)
			}).sheet(isPresented: $showImagePicker, content: {
				ImagePicker(sourceType: imagePickerSourceType) { image in
					guard let selectedImage = image else {
						return
					}

					self.selectedImage = selectedImage
				}
			}).popup(isPresented: $showToast) {
                VStack {
                    Text(toastText)
                        .padding(25)
                        .background(Color.init(white: 0.1))
                        .cornerRadius(3.0)
                }
			} customize: {
				$0
					.type(.toast)
					.position(.center)
					.autohideIn(5)
			}
				.padding()
				.navigationTitle("七牛上传")
				.foregroundColor(kMainColor)
		}
	}
    
    private func cancel() {
        isCancel = true
    }
    
	private func upload() {
        Uploader.uploadImage(image: selectedImage, key: key, mimeType: mimeType) { send, total in
            processValue = CGFloat(send) / CGFloat(total)
        } cancel: {
            return isCancel
        } complete: { response, responseData in
            btnTitle = kUploadBtnTextUpload
            processValue = 0
            
            isCancel = false
            toastText = "response:\n\(String(describing: response))"
            showToast = true
            print("====== \(toastText)")
        }
	}
}


#Preview {
	ContentView()
}
