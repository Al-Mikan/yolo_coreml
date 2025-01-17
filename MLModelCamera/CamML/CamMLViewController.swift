//
//  ViewController.swift
//  CoreMLPlayground
//
//  Created by Shuichi Tsutsumi on 2018/06/14.
//  Copyright © 2018 Shuichi Tsutsumi. All rights reserved.
//

import UIKit
import CoreML
import Vision

class CamMLViewController: UIViewController {

    private var videoCapture: VideoCapture!
    private let serialQueue = DispatchQueue(label: "com.toyoshin")
    
    private let videoSize = CGSize(width: 1280, height: 720)
    private let preferredFps: Int32 = 2
    
    private var modelUrls: [URL]!
    private var selectedVNModel: VNCoreMLModel?
    private var selectedModel: MLModel?
    @IBOutlet private weak var previewView: UIView!
    @IBOutlet private weak var modelLabel: UILabel!
    @IBOutlet private weak var bbView: BoundingBoxView!
    @IBOutlet weak var loadingIcon: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let spec = VideoSpec(fps: preferredFps, size: videoSize)
        let frameInterval = 1.0 / Double(preferredFps)
        
        videoCapture = VideoCapture(cameraType: .back,
                                    preferredSpec: spec,
                                    previewContainer: previewView.layer)

        videoCapture.imageBufferHandler = {[unowned self] (imageBuffer, timestamp, outputBuffer) in
            let delay = CACurrentMediaTime() - timestamp.seconds
            if delay > frameInterval {
                return
            }

            self.serialQueue.async {
                self.runModel(imageBuffer: imageBuffer)
            }
        }
        
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
                self.loadingIcon.stopAnimating()
            }
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let videoCapture = videoCapture else {return}
        videoCapture.startCapture()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let videoCapture = videoCapture else {return}
        videoCapture.resizePreview()
        // TODO: Should be dynamically determined
        self.bbView.updateSize(for: CGSize(width: videoSize.height, height: videoSize.width))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        guard let videoCapture = videoCapture else {return}
        videoCapture.stopCapture()
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Private
    
    private func showActionSheet() {
        let alert = UIAlertController(title: "CoreMLモデル一覧", message: "モデルを選択", preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        for modelUrl in modelUrls {
            let action = UIAlertAction(title: modelUrl.modelName, style: .default) { (action) in
                self.selectModel(url: modelUrl)
            }
            alert.addAction(action)
        }
        present(alert, animated: true, completion: nil)
    }
    
    private func selectModel(url: URL) {
        selectedModel = try! MLModel(contentsOf: url)
        do {
            selectedVNModel = try VNCoreMLModel(for: selectedModel!)
            modelLabel.text = url.modelName
        }
        catch {
            fatalError("Could not create VNCoreMLModel instance from \(url). error: \(error).")
        }
    }
    
    private func runModel(imageBuffer: CVPixelBuffer) {
        guard let model = selectedVNModel else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer)
        //リクエストの作成
        let request = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
            //推論結果
            if #available(iOS 12.0, *), let results = request.results as? [VNRecognizedObjectObservation] {
                self.processObjectDetectionObservations(results)
            }
        })
        
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = .scaleFill
        do {
            try handler.perform([request])
        } catch {
            print("failed to perform")
        }
    }

    @available(iOS 12.0, *)
    private func processObjectDetectionObservations(_ results: [VNRecognizedObjectObservation]) {
        bbView.observations = results
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.bbView.isHidden = false
            self.bbView.setNeedsDisplay()
        }
    }

    // MARK: - Actions
    
    @IBAction func modelBtnTapped(_ sender: UIButton) {
        showActionSheet()
    }
    
    @IBAction func blurTapped(_ sender: UIBarButtonItem) {      bbView.blurMode.toggle()
        if bbView.blurMode==true{
            sender.image = UIImage(systemName: "person.2.slash.fill")
        }else{
            sender.image = UIImage(systemName: "person.2.fill")

        }
    }
    
    
}

extension CamMLViewController: UIPopoverPresentationControllerDelegate {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "popover" {
            let vc = segue.destination
            vc.modalPresentationStyle = UIModalPresentationStyle.popover
            vc.popoverPresentationController!.delegate = self
        }
        
        if let modelDescriptionVC = segue.destination as? ModelDescriptionViewController, let model = selectedModel {
            modelDescriptionVC.modelDescription = model.modelDescription
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

extension URL {
    var modelName: String {
        let modelNameWithID = lastPathComponent.replacingOccurrences(of: ".mlmodelc", with: "")
        let modelName=modelNameWithID.split(separator: "_")[0]
        return String(modelName)
    }
}
