import SwiftUI

struct ImageCropperView: View {
    @Environment(\.dismiss) var dismiss
    let image: UIImage
    let onCrop: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    let boxSize: CGFloat = 300
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // The manipulatable image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: boxSize, height: boxSize)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { val in
                                let delta = val / lastScale
                                lastScale = val
                                scale = min(max(scale * delta, 1), 5)
                            }
                            .onEnded { _ in lastScale = 1.0 }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { val in
                                offset = CGSize(
                                    width: lastOffset.width + val.translation.width,
                                    height: lastOffset.height + val.translation.height
                                )
                            }
                            .onEnded { _ in lastOffset = offset }
                    )
                
                // Dimming mask outside the circle
                Rectangle()
                    .fill(Color.black.opacity(0.7))
                    .mask(
                        ZStack {
                            Rectangle().fill(Color.white)
                            Circle()
                                .fill(Color.black)
                                .frame(width: boxSize, height: boxSize)
                        }
                        .compositingGroup()
                        .luminanceToAlpha()
                    )
                    .allowsHitTesting(false)
                
                // Circular border guide
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    .frame(width: boxSize, height: boxSize)
                    .allowsHitTesting(false)
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        cropAndSave()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    @MainActor
    private func cropAndSave() {
        let renderView = ZStack {
            Color.black
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: boxSize, height: boxSize)
                .scaleEffect(scale)
                .offset(offset)
        }
        .frame(width: boxSize, height: boxSize)
        .clipped()
        
        let renderer = ImageRenderer(content: renderView)
        renderer.scale = UIScreen.main.scale
        if let croppedImage = renderer.uiImage {
            onCrop(croppedImage)
            dismiss()
        } else {
            dismiss()
        }
    }
}
