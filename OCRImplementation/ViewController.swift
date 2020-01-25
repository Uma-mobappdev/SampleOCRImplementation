//
//  ViewController.swift
//  OCRImplementation
//
//  Created by Umamaheshwari on 07/01/20.
//  Copyright © 2020 Umamaheshwari. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation
import Firebase

class ViewController: UIViewController, UINavigationControllerDelegate {

    //Properties
    lazy var vision = Vision.vision()
    var textRecognizer: VisionTextRecognizer?
    
    @IBOutlet weak var labelDetectedOCR: UILabel!
    @IBOutlet weak var buttonCapture: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textRecognizer = vision.onDeviceTextRecognizer()
    }


    @IBAction func handlerToCapture(_ sender: Any) {
        if(UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.camera))
        {
            AVCaptureDevice.requestAccess(for: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.video))) { response in
                
                if response {
                    //access granted
                    DispatchQueue.main.async {
                        let imagePickerController = UIImagePickerController()
                        imagePickerController.delegate = self
                        imagePickerController.sourceType = .camera
                        imagePickerController.cameraDevice = .front
                        imagePickerController.mediaTypes = [(kUTTypeImage as String)]
                        imagePickerController.allowsEditing = true
                        self.present(imagePickerController, animated: true, completion: nil)
                    }
                    print("access Granted")
                } else {
                    print("access denied")
                    self.checkForCameraAccess()
                    return
               }
            }
        }
        else
        {
            let alert  = UIAlertController(title: "Warning", message: "You don't have camera.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }
    
    func checkForCameraAccess(){
        let authStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.video)))
        switch authStatus {
        case .authorized: print("authorized")
        case .notDetermined: print("Not Allow")
        AVCaptureDevice.requestAccess(for: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.video))) { success in
            if success {
                print("Permission granted, proceed")
            } else {
                print("Permission denied")
            }
            }
        case .denied: self.alertToAllowCameraAccess()
        default: print("default")
        }
    }
    
    func alertToAllowCameraAccess() {
        DispatchQueue.main.async {
            
            let alert = UIAlertController(
                title: "IMPORTANT",
                message: "Camera access required for capturing photos! Kindly Enable Camera in Settings",
                preferredStyle: UIAlertController.Style.alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (alert) -> Void in
                
            }))
            
            alert.addAction(UIAlertAction(title: "Allow Camera", style: .cancel, handler: { (alert) -> Void in
                UIApplication.shared.openURL(URL(string: UIApplication.openSettingsURLString)!)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        var arrayOfOCRText:[String] = []
        picker.dismiss(animated: true, completion: nil)
        if let imageCropped = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage {
            let visionImage = VisionImage(image: imageCropped)
            textRecognizer?.process(visionImage, completion: { (result, error) in
                guard error == nil, let result = result else {
                    // ...
                    return
                }
                for block in result.blocks {
                    let blockText = block.text
                    let tagger = NSLinguisticTagger(tagSchemes: [.nameType], options: 0)
                    tagger.string = blockText
                    let range = NSRange(location:0, length: blockText.utf16.count)
                    let options: NSLinguisticTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
                    let tags: [NSLinguisticTag] = [.personalName, .placeName, .organizationName]
                    if #available(iOS 11.0, *) {
                        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType, options: options) { tag, tokenRange, stop in
                            if let tag = tag, tags.contains(tag) {
                                let name = (blockText as NSString).substring(with: tokenRange)
                                print("\(name): \(tag)")
                                arrayOfOCRText.append(name)
                            }
                        }
                    } else {
                        // Fallback on earlier versions
                    }
                    let detectorType: NSTextCheckingResult.CheckingType = [.phoneNumber, .link, .address]
                    do {
                        let detector = try NSDataDetector(types: detectorType.rawValue)
                        let results = detector.matches(in: blockText, options: [], range:
                            NSRange(location: 0, length: blockText.utf16.count))
                        
                        for result in results {
                            if let matchURL = result.url,
                                let matchURLComponents = URLComponents(url: matchURL, resolvingAgainstBaseURL: false),
                                matchURLComponents.scheme == "mailto"
                            {
                                let address = matchURLComponents.path
                                print("mail:\(address)")
                                arrayOfOCRText.append(address)
                            }
                            if let range = Range(result.range, in: blockText), result.resultType.rawValue == 2048 {
                                let matchResult = blockText[range]
                                print("result: \(matchResult), range: \(result.range)")
                                arrayOfOCRText.append(String(matchResult))
                            }
                        }
                        
                    } catch {
                        print("handle error")
                    }
                    if arrayOfOCRText.count > 0 {
                        for text in arrayOfOCRText {
                            self.labelDetectedOCR.text! += text+"\n"
                        }
                    }
                }
            })

        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
    return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVMediaType(_ input: AVMediaType) -> String {
    return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
    return input.rawValue
}
