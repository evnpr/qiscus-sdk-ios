//
//  QCellMediaLeft.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/4/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import ImageViewer

class QCellMediaLeft: QChatCell {

    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var imageDisplay: UIImageView!
    @IBOutlet weak var videoFrame: UIImageView!
    @IBOutlet weak var downloadButton: ChatFileButton!
    @IBOutlet weak var videoPlay: UIImageView!
    @IBOutlet weak var progressContainer: UIView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var balloonView: UIImageView!
    
    @IBOutlet weak var progressHeight: NSLayoutConstraint!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
    
    let defaultDateLeftMargin:CGFloat = -10
    var tapRecognizer: UITapGestureRecognizer?
    let maxProgressHeight:CGFloat = 40
    var isVideo = false
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        progressContainer.layer.cornerRadius = 20
        progressContainer.clipsToBounds = true
        progressContainer.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.65).cgColor
        progressContainer.layer.borderWidth = 2
        downloadButton.setImage(Qiscus.image(named: "ic_download_chat")!.withRenderingMode(.alwaysOriginal), for: UIControlState())
        self.videoPlay.image = Qiscus.image(named: "play_button")
        self.videoFrame.image = Qiscus.image(named: "movie_frame")?.withRenderingMode(.alwaysTemplate)
        self.videoFrame.tintColor = UIColor.black
        self.videoFrame.layer.cornerRadius = 10
        self.videoPlay.contentMode = .scaleAspectFit
        self.imageDisplay.contentMode = .scaleAspectFill
        self.imageDisplay.clipsToBounds = true
        self.imageDisplay.backgroundColor = UIColor.black
        self.imageDisplay.isUserInteractionEnabled = true
        imageDisplay.layer.cornerRadius = 10
    }
    
    public override func commentChanged() {
        balloonView.tintColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
        self.balloonView.image = self.getBallon()
        progressContainer.isHidden = true
        progressView.isHidden = true
        
        if let file = self.comment!.file {
            if let image = self.comment!.displayImage {
                self.imageDisplay.image = image
            }
            else if QFileManager.isFileExist(inLocalPath: file.localThumbPath){
                imageDisplay.loadAsync(fromLocalPath: file.localThumbPath, onLoaded: { (image, _) in
                    self.imageDisplay.image = image
                    self.comment!.displayImage = image
                })
            }else if QFileManager.isFileExist(inLocalPath: file.localMiniThumbPath){
                imageDisplay.loadAsync(fromLocalPath: file.localMiniThumbPath, onLoaded: { (image, _) in
                    self.imageDisplay.image = image
                    self.comment!.displayImage = image
                })
            }else{
                imageDisplay.loadAsync(file.thumbURL, onLoaded: { (image, _) in
                    self.imageDisplay.image = image
                    self.comment!.displayImage = image
                    file.saveThumbImage(withImage: image)
                })
            }
            if self.tapRecognizer != nil{
                imageDisplay.removeGestureRecognizer(self.tapRecognizer!)
                tapRecognizer = nil
            }
            if self.comment!.cellPos == .first || self.comment!.cellPos == .single{
                if let sender = self.comment?.sender {
                    self.userNameLabel.text = sender.fullname.capitalized
                }else{
                    self.userNameLabel.text = self.comment?.senderName.capitalized
                }
                self.userNameLabel.isHidden = false
                self.topMargin.constant = 20
                self.cellHeight.constant = 20
            }else{
                self.userNameLabel.text = ""
                self.userNameLabel.isHidden = true
                self.topMargin.constant = 0
                self.cellHeight.constant = 0
            }
            
            if self.comment!.type == .video {
                self.videoPlay.image = Qiscus.image(named: "play_button")
                self.videoFrame.isHidden = false
                self.videoPlay.isHidden = false
            }else if file.ext == "gif"{
                self.videoPlay.image = Qiscus.image(named: "ic_gif")
                self.videoFrame.isHidden = true
                self.videoPlay.isHidden = false
            }else{
                self.videoPlay.isHidden = true
                self.videoFrame.isHidden = true
            }
            
            dateLabel.text = self.comment!.time.lowercased()
            progressLabel.isHidden = true
            dateLabel.textColor = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
            
            self.downloadButton.removeTarget(nil, action: nil, for: .allEvents)
            
            if !QFileManager.isFileExist(inLocalPath: file.localPath){
                if self.comment!.isDownloading {
                    self.downloadButton.isHidden = true
                    self.progressLabel.text = "\(Int(self.comment!.progress * 100)) %"
                    self.progressLabel.isHidden = false
                    self.progressContainer.isHidden = false
                    self.progressView.isHidden = false
                    let newHeight = self.comment!.progress * maxProgressHeight
                    self.progressHeight.constant = newHeight
                    self.progressView.layoutIfNeeded()
                }else{
                    self.videoPlay.isHidden = true
                    self.downloadButton.comment = self.comment!
                    self.downloadButton.addTarget(self, action: #selector(QCellMediaLeft.downloadMedia(_:)), for: .touchUpInside)
                    self.downloadButton.isHidden = false
                }
            }else{
                file.updateLocalPath(path: "")
                self.downloadButton.isHidden = true
                tapRecognizer = UITapGestureRecognizer(target:self,action:#selector(QCellMediaLeft.didTapImage))
                imageDisplay.addGestureRecognizer(tapRecognizer!)
                if self.comment!.isUploading{
                    self.progressContainer.isHidden = false
                    self.progressView.isHidden = false
                    let newHeight = self.comment!.progress * maxProgressHeight
                    self.progressHeight.constant = newHeight
                    self.progressView.layoutIfNeeded()
                    if self.comment?.type == .video {
                        self.videoPlay.isHidden = true
                    }
                }
            }
            self.balloonView.layoutIfNeeded()
        }
    }
    open override func setupCell(){
        
    }
    
    open func downloadMedia(_ sender: ChatFileButton){
        sender.isHidden = true
        if let room = QRoom.room(withId: comment!.roomId){
            room.downloadMedia(onComment: self.comment!)
        }
    }
    
    public override func downloadingMedia() {
        self.downloadButton.isHidden = true
        self.progressLabel.text = "\(Int(self.comment!.progress * 100)) %"
        self.progressLabel.isHidden = false
        self.progressContainer.isHidden = false
        self.progressView.isHidden = false
        
        let newHeight = self.comment!.progress * maxProgressHeight 
        self.progressHeight.constant = newHeight
        UIView.animate(withDuration: 0.65, animations: {
            self.progressView.layoutIfNeeded()
        })
    }
    public override func downloadFinished() {
        if let file = self.comment!.file {
            if QFileManager.isFileExist(inLocalPath: file.localPath){
                imageDisplay.loadAsync(fromLocalPath: file.localPath, onLoaded: { (image, _) in
                    self.imageDisplay.image = image
                    self.comment!.displayImage = image
                })
            }else if QFileManager.isFileExist(inLocalPath: file.localMiniThumbPath){
                imageDisplay.loadAsync(fromLocalPath: file.localMiniThumbPath, onLoaded: { (image, _) in
                    self.imageDisplay.image = image
                    self.comment!.displayImage = image
                })
            }else{
                self.videoPlay.isHidden = true
                self.downloadButton.comment = self.comment!
                self.downloadButton.addTarget(self, action: #selector(QCellMediaLeft.downloadMedia(_:)), for: .touchUpInside)
                self.downloadButton.isHidden = false
            }
            self.progressView.isHidden = true
            self.progressContainer.isHidden = true
            self.progressLabel.isHidden = true
            if self.comment!.type == .video {
                self.videoPlay.image = Qiscus.image(named: "play_button")
                self.videoFrame.isHidden = false
                self.videoPlay.isHidden = false
            }else if file.ext == "gif"{
                self.videoPlay.image = Qiscus.image(named: "ic_gif")
                self.videoFrame.isHidden = true
                self.videoPlay.isHidden = false
            }else{
                self.videoPlay.isHidden = true
                self.videoFrame.isHidden = true
            }
            self.tapRecognizer = UITapGestureRecognizer(target:self,action:#selector(self.didTapImage))
            self.imageDisplay.addGestureRecognizer(tapRecognizer!)
        }
    }
    func didTapImage(){
        if !self.comment!.isUploading && !self.comment!.isDownloading {
            delegate?.didTapCell(withData: self.comment!)
        }
    }
    
    func setupImageView(){
        
    }
    public override func updateUserName() {
        if let sender = self.comment?.sender {
            self.userNameLabel.text = sender.fullname
        }else{
            self.userNameLabel.text = self.comment?.senderName
        }
    }
    public override func comment(didChangePosition position: QCellPosition) {
        self.balloonView.image = self.getBallon()
    }
    public override func comment(didDownload downloading:Bool){
        self.downloadFinished()
    }
    public override func comment(didUpload uploading:Bool){
        self.uploadFinished()
    }
    public override func comment(didChangeProgress progress:CGFloat){
        self.downloadButton.isHidden = true
        self.progressLabel.text = "\(Int(progress * 100)) %"
        self.progressLabel.isHidden = false
        self.progressContainer.isHidden = false
        self.progressView.isHidden = false
        
        let newHeight = progress * maxProgressHeight
        self.progressHeight.constant = newHeight
        UIView.animate(withDuration: 0.65, animations: {
            self.progressView.layoutIfNeeded()
        })
    }
}
