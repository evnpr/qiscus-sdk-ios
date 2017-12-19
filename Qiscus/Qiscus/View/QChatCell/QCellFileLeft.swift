//
//  QCellFileLeft.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/6/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

class QCellFileLeft: QChatCell {

    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var fileContainer: UIView!
    @IBOutlet weak var fileIcon: UIImageView!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var fileTypeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    @IBOutlet weak var balloonWidth: NSLayoutConstraint!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var leftMargin: NSLayoutConstraint!
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
        
    @IBOutlet weak var viewNameFile: UIView!
    @IBOutlet weak var imagePreview: UIImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
        fileContainer.roundCorners([.bottomRight, .topLeft, .topRight], radius: 12)
        fileIcon.image = Qiscus.image(named: "hd_pdf")
        fileIcon.contentMode = .scaleAspectFit
        imagePreview.roundCorners([.bottomRight, .topLeft, .topRight], radius: 12)
        viewNameFile.roundCorners(.bottomRight, radius: 12)
        imagePreview.clipsToBounds = true
    }
    public override func commentChanged() {
        userNameLabel.isHidden = true
        topMargin.constant = 0
        cellHeight.constant = 0
        balloonView.image = getBallon()
        
        let preferredLanguage = NSLocale.preferredLanguages[0]
        
        var page  : String = "Halaman"
        if(preferredLanguage.range(of:"id") != nil){
            page = "Halaman"
        }else{
            page = "Page"
        }
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(QChatCell.showFile))
        fileContainer.addGestureRecognizer(tapRecognizer)
        
        if self.comment!.cellPos == .first || self.comment!.cellPos == .single{
            if let sender = self.comment?.sender {
                self.userNameLabel.text = sender.fullname
            }else{
                self.userNameLabel.text = self.comment?.senderName
            }
            userNameLabel.isHidden = false
            topMargin.constant = 20
            cellHeight.constant = 20
            
        }
        
        if let file = self.comment!.file {
            fileNameLabel.text = file.filename
//            if file.ext == "pdf" || file.ext == "pdf_" || file.ext == "doc" || file.ext == "docx" || file.ext == "ppt" || file.ext == "pptx" || file.ext == "xls" || file.ext == "xlsx" || file.ext == "txt" {
//                fileTypeLabel.text = "\(file.ext.uppercased()) File"
//            }else{
//                fileTypeLabel.text = "Unknown File"
//            }
            
            if file.ext == "pdf" || file.ext == "pdf_"{
                var fileUrl = file.url
                
                let filename = file.filename
                print("filename =\(filename)")
                if(filename == fileUrl){
                    let filePath = file.localPath
                    print("filePath =\(filePath)")
                    do {
                        
                        let pdfdata = try NSData(contentsOfFile: filePath, options: NSData.ReadingOptions.init(rawValue: 0))
                        
                        let pdfData = pdfdata as CFData
                        let provider:CGDataProvider = CGDataProvider(data: pdfData)!
                        let pdfDoc:CGPDFDocument = CGPDFDocument(provider)!
                        print("cek page =\(pdfDoc.numberOfPages)")
                        let pdfPage:CGPDFPage = pdfDoc.page(at: 1)!
                        var pageRect:CGRect = pdfPage.getBoxRect(.mediaBox)
                        pageRect.size = CGSize(width:pageRect.size.width, height:pageRect.size.height)
                        
                        print("\(pageRect.width) by \(pageRect.height)")
                        
                        UIGraphicsBeginImageContext(pageRect.size)
                        let context:CGContext = UIGraphicsGetCurrentContext()!
                        context.saveGState()
                        context.translateBy(x: 0.0, y: pageRect.size.height)
                        context.scaleBy(x: 1.0, y: -1.0)
                        context.concatenate(pdfPage.getDrawingTransform(.mediaBox, rect: pageRect, rotate: 0, preserveAspectRatio: true))
                        context.drawPDFPage(pdfPage)
                        context.restoreGState()
                        let pdfImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
                        UIGraphicsEndImageContext()
                        
                        self.imagePreview.image = pdfImage
                        self.comment!.displayImage = pdfImage
                        file.saveMiniThumbImage(withImage: pdfImage)
                        
                        let byteCount = pdfdata.length
                        let bcf = ByteCountFormatter()
                        bcf.allowedUnits = [.useMB]
                        bcf.countStyle = .file
                        let stringSize = bcf.string(for: byteCount)?.replacingOccurrences(of: ",", with: ".")
                        
                        if(pdfDoc.numberOfPages > 1){
                            page = "pages"
                        }
                        
                        fileTypeLabel.text = stringSize! + " \u{2022} \(pdfDoc.numberOfPages) \(page)"
                        self.comment!.displayFilePage = String(pdfDoc.numberOfPages)
                        self.comment!.displayFileSize = stringSize!
                        
                    }
                    catch {
                        
                    }
                }else if(self.comment!.displayImage == nil){
                    print("fileUrl =\(fileUrl)")
                    
                    let replacedUrl = fileUrl.replacingOccurrences(of: ".pdf", with: ".jpg")
                    print("replacedUrl =\(replacedUrl)")
                    
                    imagePreview.loadAsync(replacedUrl, onLoaded: { (image, _) in
                        self.imagePreview.image = image
                        self.comment!.displayImage = image
                        file.saveMiniThumbImage(withImage: image)
                    })
                    
                    var fileSize : Double

                    do {

                        let openURL = URL(string:  fileUrl)
                        let pdfdata = NSData(contentsOf: openURL!)

                        let pdfData = pdfdata as! CFData
                        let provider:CGDataProvider = CGDataProvider(data: pdfData)!
                        let pdfDoc:CGPDFDocument = CGPDFDocument(provider)!

                        let byteCount = pdfdata?.length
                        let bcf = ByteCountFormatter()
                        bcf.allowedUnits = [.useMB]
                        bcf.countStyle = .file
                        let stringSize = bcf.string(for: byteCount)?.replacingOccurrences(of: ",", with: ".")
                        
                        if(pdfDoc.numberOfPages > 1){
                            page = "pages"
                        }

                        fileTypeLabel.text = stringSize! + " \u{2022} \(pdfDoc.numberOfPages) \(page)"
                        self.comment!.displayFilePage = String(pdfDoc.numberOfPages)
                        self.comment!.displayFileSize = stringSize!
                    } catch {
                        print("Error: \(error)")
                    }
                    
                    
                }else{
                    
                    if(self.comment!.displayFilePage! > "1"){
                        page = "pages"
                    }
                    
                    self.imagePreview.image = self.comment!.displayImage
                    self.fileTypeLabel.text = self.comment!.displayFileSize! + " \u{2022} \(self.comment!.displayFilePage!) \(page)"
                }
                
                
            }
            
        }
        
        dateLabel.text = self.comment!.time.lowercased()
        balloonView.tintColor = UIColor(red: 222/255.0, green: 222/255.0, blue: 222/255.0, alpha: 1)
        dateLabel.textColor = QiscusColorConfiguration.sharedInstance.timeLabelTextColor
        fileIcon.tintColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
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
}

