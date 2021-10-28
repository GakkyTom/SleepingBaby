//
//  ViewController.swift
//  SleepingBaby
//
//  Created by 板垣智也 on 2021/10/27.
//

import UIKit
import AVKit
import CoreML
import Vision

class ViewController: UIViewController {

    @IBOutlet weak var cameraDisplay: UIImageView!
    @IBOutlet weak var resultLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    // camera設定の詳細については下記記事を参照
    // https://qiita.com/t_okkan/items/f2ba9b7009b49fc2e30a
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        let session = AVCaptureSession()
        // cameraの画質設定
        session.sessionPreset = .hd1920x1080

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        cameraDisplay.layer.addSublayer(previewLayer)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "CameraOutput"))
        session.addInput(input)
        session.addOutput(output)

        session.startRunning()
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let sampleBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        scanImage(buffer: sampleBuffer)
    }

    private func scanImage(buffer: CVPixelBuffer) {
        guard let model = try? VNCoreMLModel(for: SleepingBabyImageClassifier(configuration: MLModelConfiguration()).model) else { return }

        let request = createRequestFor(model)
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])

        do {
            try requestHandler.perform([request])
        } catch {
            print(error)
        }
    }

    private func createRequestFor(_ model: VNCoreMLModel) -> VNCoreMLRequest {
        let request = VNCoreMLRequest(model: model) { request, _ in
            guard let results = request.results as? [VNClassificationObservation],
                  let mostConfidentResult = results.first else { return }

            if mostConfidentResult.confidence < 0.9 {
                self.resultLabel.text = "I don't know"

                return
            }

            DispatchQueue.main.async {
                let confidenceText = "\n \(Int(mostConfidentResult.confidence * 100))% confidence"
                switch mostConfidentResult.identifier {
                case "sleep":
                    self.resultLabel.text = "sleep \(confidenceText)"
                case "cry":
                    self.resultLabel.text = "cry \(confidenceText)"
                default:
                    return
                }
            }
        }

        return request
    }
}
