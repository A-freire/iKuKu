//
//  QRCodeGen.swift
//  iKuKu
//
//  Created by Adrien Freire on 22/01/2025.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeGeneratorView: View {
    @State var text: String = "https://apple.com"
    @State private var qrImage: UIImage?

    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        VStack {
            if let image = qrImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 500, height: 500)
                    .padding()
            } else {
                Text("QR Code non valide")
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            generateQRCode(from: text)
        }
    }

    // Génère un QR Code à partir d'une chaîne de caractères
    func generateQRCode(from string: String) {
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                qrImage = UIImage(cgImage: cgimg)
            }
        }
    }
}

