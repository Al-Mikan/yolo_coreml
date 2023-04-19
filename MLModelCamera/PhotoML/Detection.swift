import Foundation
import Vision
import UIKit

extension PhotoMLViewController {
    
    func detectPartsVisualizing(ciImage:CIImage) -> CIImage {
        frame += 1
        DispatchQueue.main.async { [weak self] in
            self?.messageLabel.isHidden = false
            self?.messageLabel.text = "\((self?.frame)!)frames proccessed"
        }
        guard let coreMLRequest = createCoreMLRequest() else {fatalError("Model initialization failed.")}
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        do {
            try handler.perform([coreMLRequest])
            
            guard let detectResults = coreMLRequest.results as? [VNDetectedObjectObservation] else { return ciImage }
            
            var detections:[Detection] = []
            for detectResult in detectResults {
                let flippedBox = CGRect(x: detectResult.boundingBox.minX, y: 1 - detectResult.boundingBox.maxY, width: detectResult.boundingBox.width, height: detectResult.boundingBox.height)
                let box = VNImageRectForNormalizedRect(flippedBox, Int(ciImage.extent.width), Int(ciImage.extent.height))
                let confidence = detectResult.confidence
                var label:String = ""
                if let recognizedResult = detectResult as? VNRecognizedObjectObservation, let classLabel = recognizedResult.labels.first?.identifier {
                    label = classLabel
                }
                let detection = Detection(box: box, confidence: confidence, label: label, color: UIColor.green//todo:色を適切に指定したい
                )
                
                detections.append(detection)
            }
                let newImage = drawRectOnImage(detections, ciImage)
            return newImage!.resize(as: ciImage.extent.size)
        } catch let error {
            print(error)
            return ciImage
        }
    }
    
    func detect(image:UIImage) {
        
        guard let coreMLRequest = createCoreMLRequest() else {fatalError("Model initialization failed.")}
        guard let ciImage = CIImage(image: image) else {fatalError("Image failed.")}
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        do {
            let start = Date()
            try handler.perform([coreMLRequest])
            
            guard let detectResults = coreMLRequest.results as? [VNDetectedObjectObservation] else { return }
            
            // モデルの実行時間を計算
            let end = Date()
            let diff = end.timeIntervalSince(start)
            print(diff)
            
            // 結果（複数の検出ボックス）をbox,label,confidenceのDetectionというstructでラップ
            var detections:[Detection] = []
            for detectResult in detectResults {
                // 結果の座標は下が０なので反転させる
                let flippedBox = CGRect(x: detectResult.boundingBox.minX, y: 1 - detectResult.boundingBox.maxY, width: detectResult.boundingBox.width, height: detectResult.boundingBox.height)
                
                // ０〜１で返ってきた座標を画像の座標に非正規化
                let box = VNImageRectForNormalizedRect(flippedBox, Int(image.size.width), Int(image.size.height))
                let confidence = detectResult.confidence
                var label:String = ""
                var color:UIColor = UIColor.green
                if let recognizedResult = detectResult as? VNRecognizedObjectObservation, let classLabel = recognizedResult.labels.first?.identifier {
                    label = classLabel
                    let firstLabelHash = recognizedResult.labels.first?.identifier.hashValue ?? 0.hashValue
                    color = UIColor(hue: (CGFloat(firstLabelHash % 256) / 512.0) + 1.0, saturation: 1, brightness: 1, alpha: 1)
                }
                let detection = Detection(box: box, confidence: confidence, label: label, color: color)
                detections.append(detection)
            }
            DispatchQueue.main.async { [weak self] in
                guard let safeSelf = self else { return }
                //　ボックスを画像に描画
                let newImage = safeSelf.drawRectOnImage(detections, CIImage(image:image)!)
                let ind = Date()
                let idiff = ind.timeIntervalSince(start)
                print("draw:\(idiff)")
                let context = CIContext()
                if let cgImage = context.createCGImage(newImage ?? CIImage(), from: newImage!.extent){
                    safeSelf.imageView.image = UIImage(cgImage: cgImage)
                }
            }
        } catch let error {
            print(error)
        }
    }
//    
//    func addAnalizingResult(image:UIImage,detections:[Detection]) {
//        var partsArray:[AnalizingResults.Result.Parts] = []
//        for detection in detections {
//            if let partsLabelIndex = classLabels.firstIndex(of: detection.label!) {
//                let bbox = AnalizingResults.Result.Parts.BBox(x: Double(detection.box.minX), y: Double(detection.box.minY), w: Double(detection.box.width), h: Double(detection.box.height))
//                let parts = AnalizingResults.Result.Parts(partsLabel: partsLabelIndex, bbox: bbox)
//                partsArray.append(parts)
//            }
//        }
//        guard let png = image.pngData() else {
//            self.presentAlert("解析できませんでした")
//            return
//        }
//        
//        let fileName = UUID().uuidString + ".png"
//            do {
//                let pngURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(fileName)
//                try png.write(to: pngURL)
//                let result = AnalizingResults.Result(filePath: fileName, angleLabel: 0, parts: partsArray)
//                self.analizingResults.results.append(result)
//                print(self.analizingResults)
//            } catch {
//                    self.presentAlert("解析できませんでした")
//                    return
//                }
//        }
}
