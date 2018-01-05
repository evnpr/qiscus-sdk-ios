//
//  QVCPickerAndMedia.swift
//  Example
//
//  Created by Ahmad Athaullah on 5/16/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import ImageViewer
import AVFoundation
import Photos

enum ErrorUploadType {
    case video
    case image
    case file
}

// MARK: - GaleryItemDataSource
extension QiscusChatVC:GalleryItemsDataSource{
    
    // MARK: - Galery Function
    public func galleryConfiguration()-> GalleryConfiguration{
        let closeButton = UIButton(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 20, height: 20)))
        closeButton.setImage(Qiscus.image(named: "close")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
        closeButton.tintColor = UIColor.white
        closeButton.imageView?.contentMode = .scaleAspectFit
        
        let seeAllButton = UIButton(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 20, height: 20)))
        seeAllButton.setTitle("", for: UIControlState())
        seeAllButton.setImage(Qiscus.image(named: "viewmode")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
        seeAllButton.tintColor = UIColor.white
        seeAllButton.imageView?.contentMode = .scaleAspectFit
        
        return [
            GalleryConfigurationItem.closeButtonMode(.custom(closeButton)),
            GalleryConfigurationItem.thumbnailsButtonMode(.custom(seeAllButton)),
            GalleryConfigurationItem.deleteButtonMode(.none)
        ]
    }
    
    public func itemCount() -> Int{
        return self.galleryItems.count
    }
    public func provideGalleryItem(_ index: Int) -> GalleryItem{
        let item = self.galleryItems[index]
        if item.isVideo{
            return GalleryItem.video(fetchPreviewImageBlock: { $0(item.image)}, videoURL: URL(string: item.url)! )
        }else{
            return GalleryItem.image { $0(item.image) }
        }
    }
}
// MARK: - UIImagePickerDelegate
extension QiscusChatVC:UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func showFileTooBigAlert(type: ErrorUploadType = .file){
        let preferredLanguage = NSLocale.preferredLanguages[0]
        
        var errorTitle  : String = "Failed to upload."
        var errorBody   : String = "The size of your file is too big."
        var cancel      : String = "Ok"
        let sizeImage   : Int = Int(Qiscus.maxUploadImageSize/1024)
        let sizeVideo   : Int = Int(Qiscus.maxUploadVideoSize/1024)
        let sizeFile    : Int = Int(Qiscus.maxUploadSizeInKB/1024)
        
        if type == .image {
            if(preferredLanguage.range(of:"id") != nil){
                errorTitle = "Gagal mengunggah"
                errorBody  = "Ukuran image terlalu besar. \nMaks. ukuran image \(sizeImage) Mb"
                cancel     = "Ok"
            }else{
                errorTitle = "Failed to upload"
                errorBody  = "The size of your image is too big. \nMax image size \(sizeImage) Mb"
                cancel     = "Ok"
            }
        }else if type == .video {
            if(preferredLanguage.range(of:"id") != nil){
                errorTitle = "Gagal mengunggah"
                errorBody  = "Ukuran video terlalu besar. \nMaks. ukuran video \(sizeVideo) Mb"
                cancel     = "Ok"
            }else{
                errorTitle = "Failed to upload"
                errorBody  = "The size of your video is too big. \nMax video size \(sizeVideo) Mb"
                cancel     = "Ok"
            }
        }else{
            if(preferredLanguage.range(of:"id") != nil){
                errorTitle = "Gagal mengunggah"
                errorBody  = "Ukuran file terlalu besar. \nMaks. ukuran file \(sizeFile) Mb"
                cancel     = "Ok"
            }else{
                errorTitle = "Failed to upload"
                errorBody  = "The size of your file is too big. \nMax File size \(sizeFile) Mb"
                cancel     = "Ok"
            }
        }
        
        let alertController = UIAlertController(title: errorTitle, message: errorBody, preferredStyle: .alert)
        let galeryActionButton = UIAlertAction(title: cancel, style: .cancel) { _ -> Void in }
        alertController.addAction(galeryActionButton)
        self.present(alertController, animated: true, completion: nil)
    }
    open func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]){
        if !self.processingFile {
            self.processingFile = true
            let time = Double(Date().timeIntervalSince1970)
            let timeToken = UInt64(time * 10000)
            let fileType:String = info[UIImagePickerControllerMediaType] as! String
            //picker.dismiss(animated: true, completion: nil)
            
            if fileType == "public.image"{
                var imageName:String = ""
                
                let image = info[UIImagePickerControllerOriginalImage] as! UIImage
                var data = UIImagePNGRepresentation(image)
                if let imageURL = info[UIImagePickerControllerReferenceURL] as? URL{
                    imageName = imageURL.lastPathComponent
                    
                    let imageNameArr = imageName.split(separator: ".")
                    let imageExt:String = String(imageNameArr.last!).lowercased()
                    
                    let gif:Bool = (imageExt == "gif" || imageExt == "gif_")
                    let jpeg:Bool = (imageExt == "jpg" || imageExt == "jpg_")
                    let png:Bool = (imageExt == "png" || imageExt == "png_")
                    let nef:Bool = (imageExt == "tif" || imageExt == "tif_")
                
                    if jpeg || nef{
                        imageName = "\(timeToken).jpg"
                        let imageSize = image.size
                        var bigPart = CGFloat(0)
                        if(imageSize.width > imageSize.height){
                            bigPart = imageSize.width
                        }else{
                            bigPart = imageSize.height
                        }
                        
                        var compressVal = CGFloat(1)
                        if(bigPart > 2000){
                            compressVal = 2000 / bigPart
                        }
                        
                        data = UIImageJPEGRepresentation(image, compressVal)!
                    }else if png{
                        data = UIImagePNGRepresentation(image)!
                    }else if gif{
                        let asset = PHAsset.fetchAssets(withALAssetURLs: [imageURL], options: nil)
                        if let phAsset = asset.firstObject {
                            let option = PHImageRequestOptions()
                            option.isSynchronous = true
                            option.isNetworkAccessAllowed = true
                            PHImageManager.default().requestImageData(for: phAsset, options: option) {
                                (gifData, dataURI, orientation, info) -> Void in
                                data = gifData
                            }
                        }
                    }
                }else{
                    imageName = "\(timeToken).jpg"
                    let imageSize = image.size
                    var bigPart = CGFloat(0)
                    if(imageSize.width > imageSize.height){
                        bigPart = imageSize.width
                    }else{
                        bigPart = imageSize.height
                    }
                    
                    var compressVal = CGFloat(1)
                    if(bigPart > 2000){
                        compressVal = 2000 / bigPart
                    }
                    
                    data = UIImageJPEGRepresentation(image, compressVal)!
                }
                
                if data != nil {
    //                let text = QiscusTextConfiguration.sharedInstance.confirmationImageUploadText
    //                let okText = QiscusTextConfiguration.sharedInstance.alertOkText
    //                let cancelText = QiscusTextConfiguration.sharedInstance.alertCancelText
                    
    //                QPopUpView.showAlert(withTarget: self, image: image, message: text, firstActionTitle: okText, secondActionTitle: cancelText,
    //                doneAction: {
    //                    self.postFile(filename: imageName, data: data!, type: .image)
    //                },
    //                cancelAction: {}
    //                )
                    let mediaSize = Double(data!.count) / 1024.0
                    if mediaSize > Qiscus.maxUploadImageSize {
                        picker.dismiss(animated: true, completion: {
                            self.processingFile = false
                            self.showFileTooBigAlert(type: .image)
                        })
                        return
                    }
                    let uploader = QiscusUploaderVC(nibName: "QiscusUploaderVC", bundle: Qiscus.bundle)
                    uploader.chatView = self
                    uploader.data = data
                    uploader.fileName = imageName
                    uploader.room = self.chatRoom
                    self.navigationController?.pushViewController(uploader, animated: true)
                    picker.dismiss(animated: true, completion: {
                        self.processingFile = false
                    })
                }
            }else if fileType == "public.movie" {
                
                let mediaURL = info[UIImagePickerControllerMediaURL] as! URL
                let fileName = mediaURL.lastPathComponent
                let fileNameArr = fileName.split(separator: ".")
                let _:NSString = String(fileNameArr.last!).lowercased() as NSString
                
                let mediaData = try? Data(contentsOf: mediaURL)
                let mediaSize = Double(mediaData!.count) / 1024.0
                if mediaSize > Qiscus.maxUploadVideoSize {
                    picker.dismiss(animated: true, completion: {
                        self.processingFile = false
                        self.showFileTooBigAlert(type: .video)
                    })
                    return
                }
                //create thumb image
                let assetMedia = AVURLAsset(url: mediaURL)
                let thumbGenerator = AVAssetImageGenerator(asset: assetMedia)
                thumbGenerator.appliesPreferredTrackTransform = true
                
                let thumbTime = CMTimeMakeWithSeconds(0, 30)
                let maxSize = CGSize(width: QiscusHelper.screenWidth(), height: QiscusHelper.screenWidth())
                thumbGenerator.maximumSize = maxSize
                
                picker.dismiss(animated: true, completion: {
                    self.processingFile = false
                })
                do{
                    let thumbRef = try thumbGenerator.copyCGImage(at: thumbTime, actualTime: nil)
                    let thumbImage = UIImage(cgImage: thumbRef)
                    
                    QPopUpView.showAlert(withTarget: self, image: thumbImage, message:"Are you sure to send this video?", isVideoImage: true,
                    doneAction: {
                        self.postFile(filename: fileName, data: mediaData!, type: .video, thumbImage: thumbImage)
                    },
                    cancelAction: {
                        Qiscus.printLog(text: "cancel upload")
                        QFileManager.clearTempDirectory()
                    }
                    )
                }catch{
                    Qiscus.printLog(text: "error creating thumb image")
                }
            }
        }
    }
    open func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UIDocumentPickerDelegate
extension QiscusChatVC: UIDocumentPickerDelegate,UIDocumentMenuDelegate{
    open func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        self.showLoading("Processing File")
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: NSFileCoordinator.ReadingOptions.forUploading, error: nil) { (dataURL) in
            do{
                var data:Data = try Data(contentsOf: dataURL, options: NSData.ReadingOptions.mappedIfSafe)
                print("data =\(Double(data.count))")
                
                let mediaSize = Double(data.count)
                let dataSize = Double(data.count) / 1024.0
                let bcf = ByteCountFormatter()
                bcf.allowedUnits = [.useMB]
                bcf.countStyle = .file
                
                
                if(bcf.string(for: mediaSize)?.range(of: "20") != nil || dataSize > Qiscus.maxUploadSizeInKB){
                    self.processingFile = false
                    self.dismissLoading()
                    self.showFileTooBigAlert(type: .file)
                    return
                }
                
                
                var fileName = dataURL.lastPathComponent.replacingOccurrences(of: "%20", with: "_")
                fileName = fileName.replacingOccurrences(of: " ", with: "_")
                
                var popupText = QiscusTextConfiguration.sharedInstance.confirmationImageUploadText
                var fileType = QiscusFileType.image
                var thumb:UIImage? = nil
                let fileNameArr = (fileName as String).split(separator: ".")
                let ext = String(fileNameArr.last!).lowercased()
                
                let gif = (ext == "gif" || ext == "gif_")
                let jpeg = (ext == "jpg" || ext == "jpg_")
                let png = (ext == "png" || ext == "png_")
                let video = (ext == "mp4" || ext == "mp4_" || ext == "mov" || ext == "mov_")
                
                var usePopup = false
                
                if jpeg{
                    let image = UIImage(data: data)!
                    let imageSize = image.size
                    var bigPart = CGFloat(0)
                    if(imageSize.width > imageSize.height){
                        bigPart = imageSize.width
                    }else{
                        bigPart = imageSize.height
                    }
                    
                    var compressVal = CGFloat(1)
                    if(bigPart > 2000){
                        compressVal = 2000 / bigPart
                    }
                    data = UIImageJPEGRepresentation(image, compressVal)!
                    thumb = UIImage(data: data)
                }else if png{
                    let image = UIImage(data: data)!
                    thumb = image
                    data = UIImagePNGRepresentation(image)!
                }else if gif{
                    let image = UIImage(data: data)!
                    thumb = image
                    let asset = PHAsset.fetchAssets(withALAssetURLs: [dataURL], options: nil)
                    if let phAsset = asset.firstObject {
                        let option = PHImageRequestOptions()
                        option.isSynchronous = true
                        option.isNetworkAccessAllowed = true
                        PHImageManager.default().requestImageData(for: phAsset, options: option) {
                            (gifData, dataURI, orientation, info) -> Void in
                            data = gifData!
                        }
                    }
                    usePopup = true
                }else if video {
                    fileType = .video
                    
                    let assetMedia = AVURLAsset(url: dataURL)
                    let thumbGenerator = AVAssetImageGenerator(asset: assetMedia)
                    thumbGenerator.appliesPreferredTrackTransform = true
                    
                    let thumbTime = CMTimeMakeWithSeconds(0, 30)
                    let maxSize = CGSize(width: QiscusHelper.screenWidth(), height: QiscusHelper.screenWidth())
                    thumbGenerator.maximumSize = maxSize
                    
                    do{
                        let thumbRef = try thumbGenerator.copyCGImage(at: thumbTime, actualTime: nil)
                        thumb = UIImage(cgImage: thumbRef)
                        popupText = "Are you sure to send this video?"
                    }catch{
                        Qiscus.printLog(text: "error creating thumb image")
                    }
                    usePopup = true
                }else{
                    usePopup = true
                    let textFirst = QiscusTextConfiguration.sharedInstance.confirmationFileUploadText
                    let textMiddle = "\(fileName as String)"
                    let textLast = QiscusTextConfiguration.sharedInstance.questionMark
                    popupText = "\(textFirst) \(textMiddle) \(textLast)"
                    fileType = QiscusFileType.file
                }
                self.dismissLoading()
                
                if usePopup {
                    QPopUpView.showAlert(withTarget: self, image: thumb, message:popupText, isVideoImage: video,
                                         doneAction: {
                                            self.postFile(filename: fileName, data: data, type: fileType, thumbImage: thumb)
                    },
                                         cancelAction: {
                                            Qiscus.printLog(text: "cancel upload")
                                            QFileManager.clearTempDirectory()
                    }
                    )
                }else{
                    let uploader = QiscusUploaderVC(nibName: "QiscusUploaderVC", bundle: Qiscus.bundle)
                    uploader.chatView = self
                    uploader.data = data
                    uploader.fileName = fileName
                    uploader.room = self.chatRoom
                    self.navigationController?.pushViewController(uploader, animated: true)
                }
                
                
            }catch _{
                self.dismissLoading()
            }
        }
    }
}
// MARK: - AudioPlayer
extension QiscusChatVC:AVAudioPlayerDelegate{
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            if let activeCell = activeAudioCell {
                activeCell.comment!.updatePlaying(playing: false)
                self.didChangeData(onCell: activeCell, withData: activeCell.comment!, dataTypeChanged: "isPlaying")
            }
            stopTimer()
            updateAudioDisplay()
        } catch _ as NSError {}
    }
    
    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let activeCell = activeAudioCell as? QCellAudioLeft{
            activeCell.comment!.updatePlaying(playing: false)
            self.didChangeData(onCell: activeCell, withData: activeCell.comment!, dataTypeChanged: "isPlaying")
        }
        stopTimer()
        updateAudioDisplay()
    }
    
    // MARK: - Audio Methods
    @objc func audioTimerFired(_ timer: Timer) {
        self.updateAudioDisplay()
    }
    
    func stopTimer() {
        audioTimer?.invalidate()
        audioTimer = nil
    }
    
    func updateAudioDisplay() {
        if let cell = activeAudioCell{
            if let currentTime = audioPlayer?.currentTime {
                cell.updateAudioDisplay(withTimeInterval: currentTime)
            }
        }
    }
}
