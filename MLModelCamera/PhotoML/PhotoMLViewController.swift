//
//  ViewController.swift
//  CoreML-YOLOv5
//
//

import UIKit
import PhotosUI
import Vision
import AVKit

class PhotoMLViewController: UIViewController, PHPickerViewControllerDelegate {
    private var modelUrls: [URL]!//モデルを格納する配列
    @IBOutlet weak var modelLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    var selectedVNModel: VNCoreMLModel?
    var selectedModel: MLModel?
    var selectedImage:UIImage?
    let loadingIcon = LoadingIcon()
    let activityIndicatorView = UIActivityIndicatorView()
    
    func createCoreMLRequest() -> VNCoreMLRequest?{
        if let vnCoreMLModel = selectedVNModel {
            let request = VNCoreMLRequest(model: vnCoreMLModel)
            request.imageCropAndScaleOption = .scaleFill
            return request
        }
        return nil
    }
   
    
    var ciContext = CIContext()
    
    enum MediaMode {
        case photo
        case video
    }
    
    var mediaMode:MediaMode = .photo

    var initializeTimer:Timer?
    var frame = 0

    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.loadingIcon.startIndicatorAnimation(viewController: self, activityIndicatorView: self.activityIndicatorView)
        let modelPaths = Bundle.main.paths(forResourcesOfType: "mlmodel", inDirectory: "models")
        DispatchQueue.global(qos: .background).async {
            self.modelUrls = []
            for modelPath in modelPaths {
                let url = URL(fileURLWithPath: modelPath)
                let compiledUrl = try! MLModel.compileModel(at: url)
                self.modelUrls.append(compiledUrl)
            }
            DispatchQueue.main.async {
                self.selectModel(url: self.modelUrls.first!)
                self.loadingIcon.stopIndicatorAnimation(viewController: self, activityIndicatorView: self.activityIndicatorView)
            }
        }
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        messageLabel.isHidden = true
        switch mediaMode {
        case .photo:
            guard let result = results.first else { return }
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error  in
                    if let image = image as? UIImage,  let safeSelf = self {
                        safeSelf.selectedImage = image
                        let correctOrientImage = safeSelf.getCorrectOrientationUIImage(uiImage: image) // iPhoneのカメラで撮った画像は回転している場合があるので画像の向きに応じて補正
                        safeSelf.detect(image: correctOrientImage)
                    }
                }
            }
            
        case .video:
            guard let result = results.first else { return }
            guard let typeIdentifier = result.itemProvider.registeredTypeIdentifiers.first else { return }
            if result.itemProvider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] (url, error) in
                    if let error = error { print("*** error: \(error)") }
                    let start = Date()
                    DispatchQueue.main.async {
                        self?.imageView.image = nil
                    }
                    if url != nil {
                        result.itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (url, error) in
                            _ = self?.applyProcessingOnVideo(videoURL: url as! URL) { ciImage in
                                let visualized = self?.detectPartsVisualizing(ciImage: ciImage)
                                return visualized
                            } _: { err, processedVideoURL in
                                let end = Date()
                                let diff = end.timeIntervalSince(start)
                                print(diff)
                                let player = AVPlayer(url: processedVideoURL!)
                                DispatchQueue.main.async {
                                    self?.messageLabel.isHidden = true
                                    let controller = AVPlayerViewController()
                                    controller.player = player
                                    self?.present(controller, animated: true) {
                                        player.play()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func selectImageButtonTapped(_ sender: UIButton) {
        presentPhPicker()
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        if let image = imageView.image{
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
      }
    @IBAction func changeModelTapped(_ sender: Any) {
        showActionSheet()
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            print(error)
            let ac = UIAlertController(title: "Save error", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        } else {
            let ac = UIAlertController(title: NSLocalizedString("saved!",value: "Saved", comment: ""), message: NSLocalizedString("Saved in photo library",value: "カメラロールに保存しました", comment: ""), preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
    }
    
    func presentPhPicker(){
        let alert = UIAlertController(title: "メディアの種類を選択", message: "", preferredStyle: .actionSheet)
        let imageAction = UIAlertAction(title: "画像", style: .default) { action in
            var configuration = PHPickerConfiguration()
            configuration.selectionLimit = 1
            configuration.filter = .images
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            self.mediaMode = .photo
            self.present(picker, animated: true)
        }
        
        let videoAction = UIAlertAction(title: "動画", style: .default) { action in
            var configuration = PHPickerConfiguration()
            configuration.selectionLimit = 1
            configuration.filter = .videos
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            self.mediaMode = .video
            self.present(picker, animated: true)
        }
        
        //キャンセル
        let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel)
        
        alert.addAction(imageAction)
        alert.addAction(videoAction)
        alert.addAction(cancelAction)
        
        
        self.present(alert, animated: true)
    }
    
    func getCorrectOrientationUIImage(uiImage:UIImage) -> UIImage {
        var newImage = UIImage()
        let ciContext = CIContext()
        switch uiImage.imageOrientation.rawValue {
        case 1:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.down),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
            
            newImage = UIImage(cgImage: cgImage)
        case 3:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.right),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
            newImage = UIImage(cgImage: cgImage)
        default:
            newImage = uiImage
        }
        return newImage
    }
    
    private func selectModel(url: URL) {
        selectedModel = try! MLModel(contentsOf: url)
        do {
            selectedVNModel = try VNCoreMLModel(for: selectedModel!)
            modelLabel.text = url.modelName
            guard let image = selectedImage else {
                return
            }
            let correctOrientImage = self.getCorrectOrientationUIImage(uiImage: image)
            self.detect(image: correctOrientImage)
        }
        catch {
            fatalError("Could not create VNCoreMLModel instance from \(url). error: \(error).")
        }
    }
    
    private func showActionSheet() {
        let alert = UIAlertController(title: "CoreMLモデル一覧", message: "モデルを選択", preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        for modelUrl in modelUrls {
            let action = UIAlertAction(title: modelUrl.modelName, style: .default) { (action) in
                //ローディング表示
                print("押した")
                DispatchQueue.main.async {
                    self.selectModel(url: modelUrl)
                }
            }
            alert.addAction(action)
        }
        present(alert, animated: true, completion: nil)
    }
}



struct Detection {
    let box:CGRect
    let confidence:Float
    let label:String?
    let color:UIColor
}
