//
//  ContentView.swift
//  Kamera2.0
//
//  Created by David Simonsson on 2025-03-15.
//

import SwiftUI

// Huvudvyn där kameraflödet och kontroller visas
struct ContentView: View {
    @StateObject private var camera = CameraViewController() // Skapar en CameraViewController och gör den till en @StateObject för att observera förändringar
    @State private var showSettings = false // State för att hantera visningen av inställningsmenyn
    
    var body: some View {
        ZStack {
            // Visar kameravyen i bakgrunden
            CameraView(controller: camera) // Visar kameran från CameraViewController
                .edgesIgnoringSafeArea(.all) // Gör att kameravyen täcker hela skärmen
            
            VStack {
                Spacer()
                
                ZStack {
                    // Kameraknappen
                    ControlButton(icon: "camera.circle.fill", size: 80) {
                        camera.capturePhoto()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    
                    HStack {
                        Spacer()
                        
                        // Inställningsknappen
                        ControlButton(icon: "gearshape.fill") {
                            showSettings.toggle()
                        }
                        .padding(.trailing, 20)
                    }
                }
                .padding(.bottom, 30) // Ställer in knapparnas avstånd från botten
            }
        }
        .sheet(isPresented: $showSettings) {
            // Visar inställningsvyn som ett sheet
            SettingsView(camera: camera) // Passar kamera-instansen till SettingsView
                .presentationDetents([.medium]) // Anger att sheetet ska vara av medium storlek
        }
    }
}

// Kontrollknappar
struct ControlButton: View {
    let icon: String // Ikon som ska användas på knappen
    var size: CGFloat = 60 // Storlek på ikonen
    let action: () -> Void // Action som ska köras när knappen trycks
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon) // Använder systemets ikoner
                .resizable()
                .frame(width: size, height: size) // Sätter storleken på ikonen
                .padding()
                .background(Circle().fill(Color.black.opacity(0.6))) // Ger knappen en rund bakgrund
                .foregroundColor(.white) // Sätter ikonen till vit
        }
    }
}

// Inställningsvyn för att justera filter
struct SettingsView: View {
    @ObservedObject var camera: CameraViewController
    
    var body: some View {
        VStack(spacing: 5) {
            
            // Slider för ljusstyrkan
            SettingsSlider(title: "Ljusstyrka", value: Binding(
                get: { Double(camera.brightness) },
                set: { camera.brightness = Float($0) }
            ), range: -1.0...1.0)
            
            // Slider för Kontrasten
            SettingsSlider(title: "Kontrast", value: Binding(
                get: { Double(camera.contrast) },
                set: { camera.contrast = Float($0) }
            ), range: 0.5...2.0)
            
            // Toggleknapp för gråskalan
            HStack {
                Text("Gråskala")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.yellow)
                    .padding(.leading, 16)
                
                Spacer()
                
                Toggle("", isOn: $camera.isGrayscale)
                    .toggleStyle(SwitchToggleStyle(tint: .yellow))
                    .padding(.trailing, 16)
            }
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.3)))
            .padding(.vertical, 4)
            
            // Återställningsknappen
            Button(action: {
                camera.resetFilters()
            }) {
                Text("Återställ")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(Color.red))
            }
            .padding(.top, 2)
            
            Spacer()
        }
        .background(Color.black)
    }
}

// Slider för ljusstyrka och kontrast
struct SettingsSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack {
            Text("\(title): \(String(format: "%.1f", value))") // Visar titel + värde på inställningen
                .font(.title) // Större text
                .bold()
                .foregroundColor(.yellow) // Gör texten mer synlig
            
            Slider(value: $value, in: range, step: 0.1)
                .accentColor(.yellow) // Tydlig färg
                .frame(height: 50) // Gör slidern tjockare
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.3)))
        }
        .padding()
    }
}

