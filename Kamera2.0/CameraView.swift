//
//  CameraView.swift
//  Kamera2.0
//
//  Created by David Simonsson on 2025-03-15.
//

import SwiftUI
import AVFoundation

// Komponent som representerar CameraViewController.
struct CameraView: UIViewControllerRepresentable {
    @ObservedObject var controller: CameraViewController // Uppdaterar kameraflödet
    
    // Skapar och returnerar en instans av CameraViewController när vyn skapas.
    func makeUIViewController(context: Context) -> CameraViewController {
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}
