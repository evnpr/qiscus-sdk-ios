//
//  QRoomService.swift
//  Example
//
//  Created by Ahmad Athaullah on 7/8/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import Foundation
import SwiftyJSON
import Alamofire
import AlamofireImage
import AVFoundation
import RealmSwift

public class QRoomService:NSObject{    
    public func sync(onRoom room:QRoom){
        if room.isInvalidated {
            return
        }
        let loadURL = QiscusConfig.ROOM_REQUEST_ID_URL
        let parameters:[String : AnyObject] =  [
            "id" : room.id as AnyObject,
            "token"  : Qiscus.shared.config.USER_TOKEN as AnyObject
        ]
        QiscusService.session.request(loadURL, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
            if let response = responseData.result.value {
                let json = JSON(response)
                let results = json["results"]
                let error = json["error"]
                
                if room.isInvalidated {
                    return
                }
                if results != JSON.null{
                    let roomData = results["room"]
                    room.syncRoomData(withJSON: roomData)
                    let commentPayload = results["comments"].arrayValue
                    for json in commentPayload {
                        let commentId = json["id"].intValue
                        print("[QISCUS QRoomService 41] json =\(json)")
                        if commentId <= QiscusMe.sharedInstance.lastCommentId {
                            room.saveOldComment(fromJSON: json)
                        }else{
                            QChatService.syncProcess()
                        }
                    }
                    room.delegate?.room(didFinishSync: room)
                }else if error != JSON.null{
                    Qiscus.printLog(text: "error getRoom")
                    
                }else{
                    Qiscus.printLog(text: "error getRoom: ")
                }
            }else{
                Qiscus.printLog(text: "error getRoom")
            }
        })
    }
    public func loadMore(onRoom room:QRoom){
        let loadURL = QiscusConfig.LOAD_URL
        var parameters =  [
            "topic_id" : room.id as AnyObject,
            "token" : Qiscus.shared.config.USER_TOKEN as AnyObject
        ]
        if room.commentsGroupCount > 0 {
            let firstComment = room.comments[0].comments[0]
            parameters["last_comment_id"] = firstComment.id as AnyObject
        }
        Qiscus.printLog(text: "request loadMore parameters: \(parameters)")
        Qiscus.printLog(text: "request loadMore url \(loadURL)")
        
        QiscusService.session.request(loadURL, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
            Qiscus.printLog(text: "loadMore result: \(responseData)")
            if let response = responseData.result.value{
                let json = JSON(response)
                let results = json["results"]
                let error = json["error"]
                if results != JSON.null{
                    let comments = json["results"]["comments"].arrayValue
                    if comments.count > 0 {
                        for newComment in comments {
                            room.saveOldComment(fromJSON: newComment)
                        }
                        room.delegate?.room(didFinishLoadMore: room, success: true, gotNewComment: true)
                    }else{
                        room.delegate?.room(didFinishLoadMore: room, success: true, gotNewComment: false)
                    }
                }else if error != JSON.null{
                    room.delegate?.room(didFinishLoadMore: room, success: false, gotNewComment: false)
                    Qiscus.printLog(text: "error loadMore: \(error)")
                }
            }else{
                room.delegate?.room(didFinishLoadMore: room, success: false, gotNewComment: false)
                Qiscus.printLog(text: "fail to LoadMore Data")
            }
        })
    }
    internal func updateRoom(onRoom room:QRoom, roomName:String? = nil, roomAvatarURL:String? = nil, roomOptions:String? = nil, onSuccess:@escaping ((_ room: QRoom)->Void),onError:@escaping ((_ error: String)->Void)){
        if Qiscus.isLoggedIn{
            if roomName != nil || roomAvatarURL != nil || roomOptions != nil {
                let requestURL = QiscusConfig.UPDATE_ROOM_URL
                
                var parameters:[String : AnyObject] = [
                    "id" : room.id as AnyObject,
                    "token" : Qiscus.shared.config.USER_TOKEN  as AnyObject
                ]
                if roomName != nil {
                    parameters["room_name"] = roomName as AnyObject
                }
                if roomAvatarURL != nil {
                    parameters["avatar_url"] = roomAvatarURL as AnyObject
                }
                if roomOptions != nil {
                    parameters["options"] = roomOptions as AnyObject
                }
                Qiscus.printLog(text: "update room parameters: \(parameters)")
                QiscusService.session.request(requestURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                    if let response = responseData.result.value {
                        Qiscus.printLog(text: "update room api response:\n\(response)")
                        let json = JSON(response)
                        let results = json["results"]
                        let error = json["error"]
                        
                        if results != JSON.null{
                            Qiscus.printLog(text: "getListComment with user response: \(responseData)")
                            let changed = json["results"]["changed"].boolValue
                            if changed {
                                if let name = roomName{
                                    room.update(name: name)
                                }
                                if let avatarURL = roomAvatarURL {
                                    room.update(avatarURL: avatarURL)
                                }
                                if let roomData = roomOptions {
                                    room.update(data: roomData)
                                }
                                onSuccess(room)
                            }else{
                                onError("No change on room data")
                            }
                        }else if error != JSON.null{
                            onError("\(error)")
                            Qiscus.printLog(text: "error update chat room: \(error)")
                        }
                    }else{
                        Qiscus.printLog(text: "fail to update chat room")
                        onError("fail to update chat room")
                    }
                })
            }else{
                onError("fail to update chat room")
            }
        }
        else{
            onError("User not logged in")
        }
    }
    public func publisComentStatus(onRoom room:QRoom, status:QCommentStatus){
        if (status == QCommentStatus.delivered || status == QCommentStatus.read) && (room.commentsGroupCount > 0){
            let loadURL = QiscusConfig.UPDATE_COMMENT_STATUS_URL
            let lastCommentId = room.lastComment!.id
            var parameters:[String : AnyObject] =  [
                "token" : Qiscus.shared.config.USER_TOKEN as AnyObject,
                "room_id" : room.id as AnyObject,
                ]
            
            if status == QCommentStatus.delivered{
                parameters["last_comment_received_id"] = lastCommentId as AnyObject
            }else{
                parameters["last_comment_read_id"] = lastCommentId as AnyObject
            }
            QiscusService.session.request(loadURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                if let response = responseData.result.value {
                    Qiscus.printLog(text: "publish message status result: \(response)")
                    let savedParticipant = room.participants.filter("email == '\(QiscusMe.sharedInstance.email)'")
                    if savedParticipant.count > 0 {
                        let participant = savedParticipant.first!
                        if status == .delivered {
                            participant.updateLastDeliveredId(commentId: lastCommentId)
                        }else{
                            participant.updateLastReadId(commentId: lastCommentId)
                        }
                    }
                }else{
                    Qiscus.printLog(text: "error update message status")
                }
            })
        }
    }
    public func postComment(onRoom roomId:String, comment:QComment, type:String? = nil, payload:JSON? = nil){
        Qiscus.printLog(text: "Start postComment idRoom = \(roomId) ::: comment = \(comment.text)")
        var parameters:[String: AnyObject] = [String: AnyObject]()
        
        parameters = [
            "comment"  : comment.text as AnyObject,
            "room_id"   : roomId as AnyObject,
            "topic_id" : roomId as AnyObject,
            "unique_temp_id" : comment.uniqueId as AnyObject,
            "disable_link_preview" : true as AnyObject,
            "token" : Qiscus.shared.config.USER_TOKEN as AnyObject
        ]
        if comment.type == .image || comment.type == .video {
            parameters["type"] = "file_attachment" as AnyObject
            parameters["payload"] = comment.data as AnyObject
        }
        if comment.type == .reply && comment.data != ""{
            parameters["type"] = "reply" as AnyObject
            parameters["payload"] = "\(comment.data)" as AnyObject
        }
        if comment.extras != nil {
            parameters["extras"] = comment.rawExtra as AnyObject
        }
        if type != nil && payload != nil {
            parameters["type"] = type as AnyObject
            parameters["payload"] = "\(payload!)" as AnyObject
        }
        switch comment.type {
        case .contact, . location:
            parameters["type"] = comment.typeRaw as AnyObject
            parameters["payload"] = comment.data as AnyObject
            break
        case .custom:
            parameters["type"] = "custom" as AnyObject
            parameters["payload"] = "\(comment.data)" as AnyObject
            break
        default:
            break
        }
        QiscusService.session.request(QiscusConfig.postCommentURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {response in
            //let statusCode = response.response?.statusCode
            
            switch response.result {
            case .success:
                if let result = response.result.value {
                    let json = JSON(result)
                    let success = (json["status"].intValue == 200)
                    
                    if success == true {
                        let commentJSON = json["results"]["comment"]
                        let commentId = commentJSON["id"].intValue
                        let commentBeforeId = commentJSON["comment_before_id"].intValue
                        
                        comment.update(commentId: commentId, beforeId: commentBeforeId)
                        Qiscus.printLog(text: "Success postComment idRoom =\(roomId)")
                        if let room = QRoom.room(withId: roomId){
                            if comment.status == QCommentStatus.sending || comment.status == QCommentStatus.failed {
                                    room.updateCommentStatus(inComment: comment, status: .sent)
                            }
                            self.sync(onRoom: room)
                        }
                    }else{
                        let status = QCommentStatus.failed
                        Qiscus.printLog(text: "Failed postComment idRoom =\(roomId) ::: status =\(status)")
                        if let room = QRoom.room(withId: roomId){
                            room.updateCommentStatus(inComment: comment, status: status)
                        }
                    }
                }else{
                    let status = QCommentStatus.failed
                    Qiscus.printLog(text: "Failed postComment ")
                    if let room = QRoom.room(withId: roomId){
                        room.updateCommentStatus(inComment: comment, status: status)
                    }
                }
                break
            case .failure(let error):
                var status = QCommentStatus.failed
                if comment.type == .text || comment.type == .reply || comment.type == .custom {
                    status = .pending
                }
                if let room = QRoom.room(withId: roomId){
                    room.updateCommentStatus(inComment: comment, status: status)
                }
                Qiscus.printLog(text: "fail to post comment idRoom =\(roomId) with error: \(error)")
                let delay = 2.0 * Double(NSEC_PER_SEC)
                let time = DispatchTime.now() + delay / Double(NSEC_PER_SEC)
                let commentTS = ThreadSafeReference(to: comment)
                DispatchQueue.main.asyncAfter(deadline: time, execute: {
                    let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                    guard let c = realm.resolve(commentTS) else { return }
                    if let room = QRoom.room(withId: roomId){
                        room.post(comment: c)
                    }
                })
                break
            }
        })
    }
    public func downloadMedia(inRoom room: QRoom, comment:QComment, thumbImageRef:UIImage? = nil, isAudioFile:Bool = false, onSuccess: ((QComment)->Void)? = nil, onError:((String)->Void)? = nil, onProgress:((Double)->Void)? = nil){
        if let file = comment.file {
            comment.updateDownloading(downloading: true)
            comment.updateProgress(progress: 0)
            let fileURL = file.url.replacingOccurrences(of: " ", with: "%20")
            let ext = file.ext
            
            QiscusRequestThread.async {
                QiscusService.session.request(fileURL, method: .get, parameters: nil, encoding: URLEncoding.default, headers: nil).responseData(completionHandler: { response in
                    Qiscus.printLog(text: "download result: \(response)")
                    switch response.result {
                    case .success:
                        if let imageData = response.data {
                            if !isAudioFile{
                                if let image = UIImage(data: imageData) {
                                    var thumbImage = UIImage()
                                    if !(ext == "gif" || ext == "gif_"){
                                        thumbImage = QFile.createThumbImage(image, fillImageSize: thumbImageRef)
                                    }
                                    
                                    var fileData = Data()
                                    if (ext == "png" || ext == "png_") {
                                        fileData = UIImagePNGRepresentation(image)!
                                    } else if(ext == "jpg" || ext == "jpg_"){
                                        fileData = UIImageJPEGRepresentation(image, 1.0)!
                                    } else if(ext == "gif" || ext == "gif_"){
                                        fileData = imageData
                                        thumbImage = image
                                    }
                                    
                                    DispatchQueue.main.async {autoreleasepool{
                                        let _ = file.saveFile(withData: fileData)
                                        file.saveThumbImage(withImage: thumbImage)
                                        
                                        comment.updateDownloading(downloading: false)
                                        comment.updateProgress(progress: 1)
                                        comment.displayImage = thumbImage
                                    }}
                                }else{
                                    DispatchQueue.main.async { autoreleasepool{
                                        let path = file.saveFile(withData: imageData)
                                        let assetMedia = AVURLAsset(url: URL(fileURLWithPath: "\(path)"))
                                        let thumbGenerator = AVAssetImageGenerator(asset: assetMedia)
                                        thumbGenerator.appliesPreferredTrackTransform = true
                                        
                                        let thumbTime = CMTimeMakeWithSeconds(0, 30)
                                        let maxSize = CGSize(width: QiscusHelper.screenWidth(), height: QiscusHelper.screenWidth())
                                        thumbGenerator.maximumSize = maxSize
                                        var thumbImage:UIImage?
                                        
                                        do{
                                            let thumbRef = try thumbGenerator.copyCGImage(at: thumbTime, actualTime: nil)
                                            thumbImage = UIImage(cgImage: thumbRef)
                                        }catch let error as NSError{
                                            Qiscus.printLog(text: "error creating thumb image: \(error.localizedDescription)")
                                        }
                                        if thumbImage != nil {
                                            file.saveThumbImage(withImage: thumbImage!)
                                        }
                                        comment.updateProgress(progress: 1)
                                        comment.updateDownloading(downloading: false)
                                    }}
                                }
                            }
                            else{
                                DispatchQueue.main.async { autoreleasepool{
                                    let _ = file.saveFile(withData: imageData)
                                    comment.updateDownloading(downloading: false)
                                    comment.updateProgress(progress: 1)
                                    
                                }}
                            }
                            DispatchQueue.main.async { autoreleasepool{
                                onSuccess?(comment)
                            }}
                        }
                        break
                    case .failure:
                        DispatchQueue.main.async { autoreleasepool{
                            comment.updateDownloading(downloading: false)
                            comment.updateProgress(progress: 1)
                            onError?("fail to download file")
                        }}
                        
                        break
                    }
                }).downloadProgress(closure: { progressData in
                    let progress = CGFloat(progressData.fractionCompleted)
                    
                    DispatchQueue.main.async { autoreleasepool{
                        comment.updateProgress(progress: progress)
                        comment.updateDownloading(downloading: true)
                        onProgress?(progressData.fractionCompleted)
                    }}
                })
            }
        }
    }
    public func publishStatus(inRoom roomId: String, commentId:Int, commentStatus:QCommentStatus){
        if commentStatus == QCommentStatus.delivered || commentStatus == QCommentStatus.read{
            QiscusRequestThread.async {autoreleasepool{
                let loadURL = QiscusConfig.UPDATE_COMMENT_STATUS_URL
                
                var parameters:[String : AnyObject] =  [
                    "token" : qiscus.config.USER_TOKEN as AnyObject,
                    "room_id" : roomId as AnyObject,
                    ]
                
                if commentStatus == QCommentStatus.delivered{
                    parameters["last_comment_received_id"] = commentId as AnyObject
                }else{
                    parameters["last_comment_read_id"] = commentId as AnyObject
                }
                DispatchQueue.global().async {
                    QiscusService.session.request(loadURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                        if let response = responseData.result.value {
                            Qiscus.printLog(text: "publish message response:\n\(response)")
                            let json = JSON(response)
                            let results = json["results"]
                            let error = json["error"]
                            
                            if results != JSON.null{
                                Qiscus.printLog(text: "success change comment status on \(commentId) to \(commentStatus.rawValue)")
                            }else if error != JSON.null{
                                Qiscus.printLog(text: "error update message status: \(error)")
                            }
                        }else{
                            Qiscus.printLog(text: "error update message status")
                        }
                    })
                }
            }}
        }
    }
    
    public func uploadCommentFile(inRoom room:QRoom, comment:QComment, onSuccess:  @escaping (QRoom, QComment)->Void, onError:  @escaping (QRoom,QComment,String)->Void, onProgress:((Double)->Void)? = nil){
        if room.isInvalidated || comment.isInvalidated {
            return
        }
        if let file = comment.file {
            let localPath = file.localPath
            let indexPath = room.getIndexPath(ofComment: comment)!
            let filename = file.filename
            let mimeType = file.mimeType
            
            QiscusFileThread.async {autoreleasepool{
            do {
                let data = try Data(contentsOf: URL(string: "file://\(localPath)")!)
                QiscusUploadThread.async { autoreleasepool{
                    let headers = QiscusConfig.sharedInstance.requestHeader
                    var urlUpload = URLRequest(url: URL(string: QiscusConfig.UPLOAD_URL)!)
                    
                    if headers.count > 0 {
                        for (key,value) in headers {
                            urlUpload.setValue(value, forHTTPHeaderField: key)
                        }
                    }
                    urlUpload.httpMethod = "POST"
                    
                    QiscusService.session.upload(multipartFormData: {formData in
                        formData.append(data, withName: "file", fileName: filename, mimeType: mimeType)
                        formData.append(QiscusMe.sharedInstance.token.data(using: .utf8)! , withName: "token")
                    }, with: urlUpload, encodingCompletion: {
                        encodingResult in
                        switch encodingResult{
                        case .success(let upload, _, _):
                            upload.responseJSON(completionHandler: {response in
                                Qiscus.printLog(text: "success upload: \(response)")
                                if let jsonData = response.result.value {
                                    let json = JSON(jsonData)
                                    if let url = json["url"].string {
                                        DispatchQueue.main.async { autoreleasepool{
                                            if file.isInvalidated || comment.isInvalidated || room.isInvalidated {
                                                return
                                            }
                                            file.update(fileURL: url)
                                            comment.update(text: "[file]\(url) [/file]")
                                            comment.updateUploading(uploading: false)
                                            comment.updateProgress(progress: 1)
                                            comment.updateStatus(status: .sent)
                                            let fileInfo = JSON(parseJSON: comment.data)
                                            let caption = fileInfo["caption"].stringValue
                                            let newData = "{\"url\":\"\(url)\", \"caption\":\"\(caption)\"}"
                                            comment.update(data: newData)
                                            onSuccess(room,comment)
                                        }}
                                    }
                                    else if json["results"].count > 0 {
                                        let jsonData = json["results"]
                                        if jsonData["file"].count > 0 {
                                            let fileData = jsonData["file"]
                                            if let url = fileData["url"].string {
                                                DispatchQueue.main.async { autoreleasepool{
                                                    if file.isInvalidated || comment.isInvalidated || room.isInvalidated {
                                                        return
                                                    }
                                                    file.update(fileURL: url)
                                                    comment.update(text: "[file]\(url) [/file]")
                                                    comment.updateUploading(uploading: false)
                                                    comment.updateProgress(progress: 1)
                                                    comment.updateStatus(status: .sent)
                                                    let fileInfo = JSON(parseJSON: comment.data)
                                                    let caption = fileInfo["caption"].stringValue
                                                    let newData = "{\"url\":\"\(url)\", \"caption\":\"\(caption)\"}"
                                                    comment.update(data: newData)
                                                    onSuccess(room,comment)
                                                }}
                                            }
                                        }
                                    }else{
                                        DispatchQueue.main.async { autoreleasepool{
                                            if comment.isInvalidated || room.isInvalidated {
                                                return
                                            }
                                            comment.updateUploading(uploading: false)
                                            comment.updateProgress(progress: 0)
                                            comment.updateStatus(status: .failed)
                                            room.delegate?.room(didChangeComment: indexPath.section, row: indexPath.item, action: "status")
                                        }}
                                        onError(room,comment,"Fail to upload file, no readable response")
                                    }
                                }else{
                                    DispatchQueue.main.async { autoreleasepool{
                                        if comment.isInvalidated || room.isInvalidated {
                                            return
                                        }
                                        comment.updateUploading(uploading: false)
                                        comment.updateProgress(progress: 0)
                                        comment.updateStatus(status: .failed)
                                        room.delegate?.room(didChangeComment: indexPath.section, row: indexPath.item, action: "status")
                                    }}
                                    onError(room,comment,"Fail to upload file, no readable response")
                                }
                            })
                            upload.uploadProgress(closure: {uploadProgress in
                                let progress = CGFloat(uploadProgress.fractionCompleted)
                                DispatchQueue.main.async { autoreleasepool{
                                    if comment.isInvalidated {
                                        return
                                    }
                                    comment.updateUploading(uploading: true)
                                    comment.updateProgress(progress: progress)
                                    onProgress?(uploadProgress.fractionCompleted)
                                }}
                            })
                            break
                        case .failure(let error):
                            DispatchQueue.main.async { autoreleasepool{
                                if comment.isInvalidated || room.isInvalidated {
                                    return
                                }
                                comment.updateUploading(uploading: false)
                                comment.updateProgress(progress: 0)
                                comment.updateStatus(status: .failed)
                                room.delegate?.room(didChangeComment: indexPath.section, row: indexPath.item, action: "status")
                            }}
                            onError(room,comment,"Fail to upload file, \(error)")
                            break
                        }
                    })
                }}
            } catch {
                DispatchQueue.main.async {
                    if comment.isInvalidated {
                        return
                    }
                    comment.updateUploading(uploading: false)
                    comment.updateProgress(progress: 0)
                    comment.updateStatus(status: .failed)
                }
                
                onError(room, comment, "Local file not found")
            }
            }}
        }
    }
    internal class func loadComments(inRoom room:QRoom, limit:Int, offset:String, onSuccess:@escaping ([QComment])->Void, onError:@escaping (String)->Void){
        let loadURL = QiscusConfig.LOAD_URL
        let parameters =  [
            "topic_id" : room.id as AnyObject,
            "token" : Qiscus.shared.config.USER_TOKEN as AnyObject,
            "after" : true as AnyObject,
            "limit" : limit as AnyObject,
            "last_comment_id" : offset as AnyObject
        ]
        
        Qiscus.printLog(text: "request loadCommentsLimit parameters: \(parameters)")
        
        QiscusService.session.request(loadURL, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
            if let response = responseData.result.value{
                let json = JSON(response)
                let results = json["results"]
                let error = json["error"]
                if results != JSON.null{
                    let comments = json["results"]["comments"].arrayValue
                        var commentsResult = [QComment]()
                        for newComment in comments.reversed() {
                            let comment = QComment.tempComment(fromJSON: newComment)
                            commentsResult.append(comment)
                            
                            if QComment.comment(withId: comment.beforeId) != nil {
                                room.saveOldComment(fromJSON: newComment)
                            }else if QComment.comment(withBeforeId: comment.id) != nil{
                                room.saveNewComment(fromJSON: newComment)
                            }
                        }
                        onSuccess(commentsResult)
                }else if error != JSON.null{
                    onError("\(error)")
                }
            }else{
                onError("fail to load comments")
            }
        })
    }
    internal class func loadComments(inRoom room:QRoom, onSuccess:@escaping ([QComment])->Void, onError:@escaping (String)->Void){
        let loadURL = QiscusConfig.LOAD_URL
        let parameters =  [
            "topic_id" : room.id as AnyObject,
            "token" : Qiscus.shared.config.USER_TOKEN as AnyObject,
            "after" : true as AnyObject
        ]
        
        Qiscus.printLog(text: "request loadCommentsLimit parameters: \(parameters)")
        
        QiscusService.session.request(loadURL, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
            if let response = responseData.result.value{
                let json = JSON(response)
                let results = json["results"]
                let error = json["error"]
                if results != JSON.null{
                    let comments = json["results"]["comments"].arrayValue
                    var commentsResult = [QComment]()
                    for newComment in comments.reversed() {
                        let comment = QComment.tempComment(fromJSON: newComment)
                        commentsResult.append(comment)
                        
                        if QComment.comment(withId: comment.beforeId) != nil {
                            room.saveOldComment(fromJSON: newComment)
                        }else if QComment.comment(withBeforeId: comment.id) != nil{
                            room.saveNewComment(fromJSON: newComment)
                        }
                    }
                    onSuccess(commentsResult)
                }else if error != JSON.null{
                    onError("\(error)")
                }
            }else{
                onError("fail to load comments")
            }
        })
    }
    internal class func loadMore(inRoom room:QRoom, limit:Int, offset:String, onSuccess:@escaping ([QComment],Bool)->Void, onError:@escaping (String)->Void){
        let loadURL = QiscusConfig.LOAD_URL
        let parameters =  [
            "topic_id" : room.id as AnyObject,
            "token" : Qiscus.shared.config.USER_TOKEN as AnyObject,
            "after" : false as AnyObject,
            "limit" : limit as AnyObject,
            "last_comment_id" : offset as AnyObject
        ]
        Qiscus.printLog(text: "request loadCommentsLimit parameters: \(parameters)")
        
        QiscusService.session.request(loadURL, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
            if let response = responseData.result.value{
                let json = JSON(response)
                let results = json["results"]
                let error = json["error"]
                if results != JSON.null{
                    let comments = json["results"]["comments"].arrayValue
                    var commentsResult = [QComment]()
                    for newComment in comments.reversed() {
                        let comment = QComment.tempComment(fromJSON: newComment)
                        commentsResult.append(comment)
                        
                        if QComment.comment(withId: comment.beforeId) != nil {
                            room.saveOldComment(fromJSON: newComment)
                        }else if QComment.comment(withBeforeId: comment.id) != nil{
                            room.saveNewComment(fromJSON: newComment)
                        }
                    }
                    var hasMoreMessage = false
                    if commentsResult.count > 0 {
                        let first = commentsResult.first!
                        if first.beforeId > 0 {
                            hasMoreMessage = true
                        }
                    }
                    onSuccess(commentsResult, hasMoreMessage)
                }else if error != JSON.null{
                    onError("\(error)")
                }
            }else{
                onError("fail to load comments")
            }
        })
    }
}
