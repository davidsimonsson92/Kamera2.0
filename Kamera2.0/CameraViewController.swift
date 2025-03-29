//
//  CameraViewController.swift
//  Kamera2.0
//
//  Created by David Simonsson on 2025-03-15.
//

import UIKit
import AVFoundation

// Hanterar kameran och bildbehandling
class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, ObservableObject {
    
    private let session = AVCaptureSession()  // Kamera-sessionen som hanterar all video och foto
    private var cameraOutput = AVCapturePhotoOutput()  // För att ta bilder
    private var videoOutput = AVCaptureVideoDataOutput()  // För att få video frame-data
    private var previewLayer: AVCaptureVideoPreviewLayer!  // Lager för att visa kamerans live-preview
    private var filterLayer = UIImageView()  // Lager för att visa filtrerad bild ovanpå preview
    private var ciContext = CIContext()  // Används för bildbehandlingen
    private var originalImage: UIImage?  // För att spara den ursprungliga bilden innan filtrering

    @Published var brightness: Float = 0.0  // Justering av ljusstyrka
    @Published var contrast: Float = 1.0  // Justering av kontrast
    @Published var isGrayscale = false  // Om bilden ska vara i gråskala

    // Körs när vyn laddas
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()  // Ställ in kamerainställningar
        setupFilterLayer()  // Ställ in lagret för att visa filter
        setupPinchGesture()  // Ställ in pinch-gester för zoom
        setupTapGesture()
        
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)  // Lyssna ifall enheten roteras
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()  // Starta generering av rotaton
    }
    
    // Förbereder kameran
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),  // Hämta kameran på baksidan
              let input = try? AVCaptureDeviceInput(device: device),  // Skapa input från kameran
              session.canAddInput(input),  // Kontrollera ifall input kan läggas till i sessionen
              session.canAddOutput(cameraOutput),  // Kontrollera om foto-output kan läggas till
              session.canAddOutput(videoOutput) else {  // Kontrollera om video-output kan läggas till
            return
        }
        
        session.addInput(input)  // Lägg till kamerainput
        session.addOutput(cameraOutput)  // Lägg till foto-output
        session.addOutput(videoOutput)  // Lägg till video-output
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))  // Sätt en delegate för att få video frames
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)  // Skapa en preview layer för att visa kamerans live-video
        previewLayer.videoGravity = .resizeAspectFill  // Ställer in hur videon ska skalas
        previewLayer.frame = view.bounds  // Fyller hela vyområdet
        view.layer.addSublayer(previewLayer)  // Lägger till preview layer som en sublayer
        
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }  // Starta kameran i en bakgrundstråd
    }
    
    // Sätter upp filtret som ska appliceras på videoströmmen
    private func setupFilterLayer() {
        filterLayer.frame = view.bounds  // Sätt filterlagrets ram till samma som vyens storlek
        filterLayer.contentMode = .scaleAspectFill  // Skalning av filterbilden
        view.addSubview(filterLayer)  // Lägg till filterlayer på vyn
        orientationChanged()  // Anpassa orienteringen av filterlagret
    }
    
    // Funktion som körs när enhetens orientering ändras
    @objc private func orientationChanged() {
        // Rotationer för de olika orienteringarna
        let rotationAngles: [UIDeviceOrientation: CGFloat] = [
            .portrait: 0,
            .landscapeLeft: -.pi / 2,
            .landscapeRight: .pi / 2,
            .portraitUpsideDown: .pi
        ]
        
        // Hämta rotationsvinkel baserat på aktuell orientering
        guard let angle = rotationAngles[UIDevice.current.orientation] else { return }
        
        DispatchQueue.main.async {
            self.previewLayer.setAffineTransform(CGAffineTransform(rotationAngle: angle))  // Rotera preview-layer
            self.previewLayer.frame = self.view.bounds  // Justera storlek på preview-layer
            self.filterLayer.transform = CGAffineTransform(rotationAngle: angle + .pi / 2)  // Rotera filterlagret
            self.filterLayer.frame = self.view.bounds  // Justera storlek på filterlagret
        }
    }
    
    // Förbereder pinch-gesture för zoom
    private func setupPinchGesture() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))  // Skapa pinch-gesture
        view.addGestureRecognizer(pinchGesture)  // Lägg till pinch-gesture på vyn
    }
    
    // Funktion som hanterar pinch-gesture och zoomar in eller ut beroende på hur mycket man förflyttar fingararna
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            try device.lockForConfiguration()  // Lås enheten för att ändra inställningar
            let zoomFactor = max(1.0, min(device.videoZoomFactor * gesture.scale, device.activeFormat.videoMaxZoomFactor))  // Beräkna ny zoomfaktor
            device.videoZoomFactor = zoomFactor  // Applicera zoom
            gesture.scale = 1.0  // Återställ gestens skala
            device.unlockForConfiguration()  // Lås upp enheten igen
        } catch {
            return
        }
    }
    
    // Förebereder tryck för fokusering
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))  // Tryck för att fokusera vid tryck
        view.addGestureRecognizer(tapGesture)
    }
    
    // Funktion som hanterar tryck och fokuserar kameran på den tryckta punkten
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        let tapPoint = sender.location(in: view)  // Hämta den punkt där man trycker
        focusAtPoint(tapPoint)  // Fokusera kameran på den punkten
        showFocusIndicator(at: tapPoint)  // Visa fokus-indikator på den tryckta punkten
    }
    
    // Funktion som fokuserar kameran på en given punkt
    func focusAtPoint(_ point: CGPoint) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {  // Kontrollera om fokus är möjligt
                device.focusPointOfInterest = point  // Sätt fokus på punkten
                device.focusMode = .autoFocus  // Sätt autofokusläge
            }
            
            device.unlockForConfiguration()  // Lås upp enheten efter ändringarna
        } catch {
            return
        }
    }
    
    // Visar en fokusindikator på skärmen
    func showFocusIndicator(at point: CGPoint) {
        let focusIndicator = UIView()
        focusIndicator.frame = CGRect(x: point.x - 25, y: point.y - 25, width: 80, height: 80)  // Ställ in indikatorns storlek
        focusIndicator.layer.cornerRadius = 40  // Gör formen rund
        focusIndicator.layer.borderWidth = 5  // Sätt kantens bredd
        focusIndicator.layer.borderColor = UIColor.yellow.cgColor // Ställer in färg
        
        view.addSubview(focusIndicator)  // Lägg till fokusindikatorn på vyn
        
        UIView.animate(withDuration: 1.0, delay: 1.5, options: [.curveEaseOut], animations: {
            focusIndicator.alpha = 0  // Får indikators opacitet att minska till 0 så den döljs efter en viss tid
        }) { _ in
            focusIndicator.removeFromSuperview()  // Ta bort indikatorn
        }
    }

    // Fångar video frames och applicerar filter
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let filteredImage = applyFilters(to: sampleBuffer) else { return }
        
        DispatchQueue.main.async {
            self.filterLayer.image = filteredImage  // Visa den filtrerade bilden på filterlagret
        }
    }
    
    // Applicerar filter på en bild från sampleBuffern
    private func applyFilters(to sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        return processImage(ciImage)
    }
    
    // Funktion som applicerar filter på en UIImage
    private func applyFilters(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        return processImage(ciImage)
    }
    
    // Applicerar ljusstyrka, kontrast och gråskala
    private func processImage(_ ciImage: CIImage) -> UIImage? {
        var filteredImage = ciImage
        
        // Justera färger för ljusstyrka och kontrast
        if let colorControls = CIFilter(name: "CIColorControls") {
            colorControls.setValue(filteredImage, forKey: kCIInputImageKey)
            colorControls.setValue(brightness, forKey: kCIInputBrightnessKey)
            colorControls.setValue(contrast, forKey: kCIInputContrastKey)
            filteredImage = colorControls.outputImage ?? filteredImage
        }
        
        // Applicera gråskala om det är inställt
        if isGrayscale, let grayscaleFilter = CIFilter(name: "CIPhotoEffectMono") {
            grayscaleFilter.setValue(filteredImage, forKey: kCIInputImageKey)
            filteredImage = grayscaleFilter.outputImage ?? filteredImage
        }
        
        if let cgImage = ciContext.createCGImage(filteredImage, from: filteredImage.extent) {
            return UIImage(cgImage: cgImage)  // Omvandla tillbaka till UIImage
        }
        return nil
    }
    
    // Tar ett foto och sparar det till kamera album
    func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings()  // Skapa inställningar för fotot
        cameraOutput.capturePhoto(with: photoSettings, delegate: self)  // Ta foto
    }

    // Hanterar fotot när det har tagits
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),  // Omvandla bilddata till UIImage
              let image = UIImage(data: imageData) else { return }
        
        self.originalImage = image  // Spara originalbilden
        
        let finalImage = applyFilters(to: image) ?? image  // Applicera eventuella filter på bilden
        let filterRotation = getFilterLayerRotationAngle()  // Hämta filterlagrets rotationsvinkel
        let rotatedImage = rotateImage(finalImage, by: filterRotation)  // Rotera bilden för att matcha filterlagrets rotation
        
        UIImageWriteToSavedPhotosAlbum(rotatedImage, self, #selector(imageSaved(_:didFinishSavingWithError:contextInfo:)), nil)  // Spara till album
    }
    
    // Hanterar när bilden har sparats
    @objc private func imageSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if error != nil {
            return
        }
    }
 
    // Funktion som hämtar rotationsvinkeln för filterlagret
    func getFilterLayerRotationAngle() -> CGFloat {
        let transform = filterLayer.transform
        return atan2(transform.b, transform.a)
    }
    
    // Roterar bild
    func rotateImage(_ image: UIImage, by angle: CGFloat) -> UIImage {
        var rotationAngle: CGFloat = 0
        
        switch angle {
        case .pi / 2:
            rotationAngle = .pi / 2
        case -.pi / 2:
            rotationAngle = -.pi / 2
        case .pi:
            rotationAngle = .pi
        default:
            return image
        }
        
        let isRotated90Degrees = abs(rotationAngle) == .pi / 2
        let newSize = isRotated90Degrees ? CGSize(width: image.size.height, height: image.size.width) : image.size
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: rotationAngle)
        
        let drawRect = CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height)
        image.draw(in: drawRect)
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
    
    // Återställer alla filterinställningar till default
    func resetFilters() {
        self.brightness = 0.0
        self.contrast = 1.0
        self.isGrayscale = false
        
        guard let originalImage = self.originalImage else { return }
        self.filterLayer.image = applyFilters(to: originalImage)
    }
}
