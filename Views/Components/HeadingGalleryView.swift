import SwiftUI

struct HeadingGalleryView: View {
    let media: [Media]
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    
    private let itemWidth: CGFloat = 300
    private let itemSpacing: CGFloat = 20
    
    // Sort media by heading for circular ordering
    private var sortedMedia: [Media] {
        let mediaWithHeading = media.filter { $0.exifData?.gpsDirection != nil }
        let mediaWithoutHeading = media.filter { $0.exifData?.gpsDirection == nil }
        
        // Sort media with heading by compass direction
        let sortedWithHeading = mediaWithHeading.sorted { media1, media2 in
            guard let heading1 = media1.exifData?.gpsDirection,
                  let heading2 = media2.exifData?.gpsDirection else { return false }
            return heading1 < heading2
        }
        
        // Append media without heading at the end
        return sortedWithHeading + mediaWithoutHeading
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Compass rose indicator
            CompassRoseView(currentHeading: currentHeading)
                .frame(height: 60)
            
            // Main gallery
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let centerOffset = screenWidth / 2 - itemWidth / 2
                
                HStack(spacing: itemSpacing) {
                    ForEach(Array(sortedMedia.enumerated()), id: \.element.id) { index, mediaItem in
                        MediaItemView(media: mediaItem)
                            .frame(width: itemWidth)
                            .scaleEffect(index == currentIndex ? 1.0 : 0.8)
                            .opacity(index == currentIndex ? 1.0 : 0.7)
                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    }
                }
                .offset(x: centerOffset - CGFloat(currentIndex) * (itemWidth + itemSpacing) + dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.x
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 100
                            let draggedIndex = -Int((value.translation.x + threshold/2) / threshold)
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if value.translation.x > threshold && currentIndex > 0 {
                                    currentIndex -= 1
                                } else if value.translation.x < -threshold && currentIndex < sortedMedia.count - 1 {
                                    currentIndex += 1
                                }
                                dragOffset = 0
                            }
                        }
                )
            }
            .frame(height: 400)
            
            // Heading info
            if let currentMedia = sortedMedia.indices.contains(currentIndex) ? sortedMedia[currentIndex] : nil {
                HeadingInfoView(media: currentMedia)
                    .padding(.horizontal)
            }
        }
        .onAppear {
            // Start with the first photo that has heading data, or first photo if none have heading
            if let firstWithHeading = sortedMedia.firstIndex(where: { $0.exifData?.gpsDirection != nil }) {
                currentIndex = firstWithHeading
            }
        }
    }
    
    private var currentHeading: Float? {
        guard sortedMedia.indices.contains(currentIndex) else { return nil }
        return sortedMedia[currentIndex].exifData?.gpsDirection
    }
}

struct MediaItemView: View {
    let media: Media
    
    var body: some View {
        ZStack {
            // Photo placeholder/actual image
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    // For now, show image name as placeholder
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(media.url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
            
            // Heading indicator overlay
            if let heading = media.exifData?.gpsDirection {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(Int(heading))°")
                            .font(.caption.bold())
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct HeadingInfoView: View {
    let media: Media
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let heading = media.exifData?.gpsDirection {
                HStack {
                    Text("Heading:")
                        .font(.headline)
                    Text("\(Int(heading))° \(compassDirection(for: heading))")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    Spacer()
                }
            } else {
                HStack {
                    Text("No heading data")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            // EXIF info
            if let exif = media.exifData {
                HStack {
                    if let iso = exif.iso {
                        Text("ISO \(iso)")
                    }
                    if let aperture = exif.fNumber {
                        Text("f/\(String(format: "%.1f", aperture))")
                    }
                    if let shutter = exif.exposureTime {
                        Text(shutter)
                    }
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func compassDirection(for heading: Float) -> String {
        switch heading {
        case 0..<22.5, 337.5...360: return "N"
        case 22.5..<67.5: return "NE"
        case 67.5..<112.5: return "E"
        case 112.5..<157.5: return "SE"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return "SW"
        case 247.5..<292.5: return "W"
        case 292.5..<337.5: return "NW"
        default: return ""
        }
    }
}

struct CompassRoseView: View {
    let currentHeading: Float?
    
    var body: some View {
        ZStack {
            // Compass circle
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                .frame(width: 50, height: 50)
            
            // Cardinal directions
            ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                Text(direction)
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .offset(y: -30)
                    .rotationEffect(.degrees(rotationForDirection(direction)))
            }
            
            // Current heading indicator
            if let heading = currentHeading {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 3, height: 20)
                    .offset(y: -15)
                    .rotationEffect(.degrees(Double(heading)))
                    .animation(.easeInOut(duration: 0.3), value: heading)
            }
            
            // Center dot
            Circle()
                .fill(Color.primary)
                .frame(width: 4, height: 4)
        }
        .frame(width: 60, height: 60)
    }
    
    private func rotationForDirection(_ direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }
}

#Preview {
    let sampleMedia = [
        Media(id: UUID(), spotId: nil, userId: UUID(), type: .photo, url: "IMG_8608", thumbnailUrl: nil, captureTimeUTC: Date(), exifData: ExifData(gpsDirection: 15), device: "iPhone 15 Pro", lens: "Main Camera", focalLengthMM: 24, aperture: 1.78, shutterSpeed: "1/125", iso: 100, presets: [], filters: [], headingFromExif: true, originalFilename: "IMG_8608.HEIC", createdAt: Date()),
        Media(id: UUID(), spotId: nil, userId: UUID(), type: .photo, url: "IMG_8609", thumbnailUrl: nil, captureTimeUTC: Date(), exifData: ExifData(gpsDirection: 90), device: "iPhone 15 Pro", lens: "Main Camera", focalLengthMM: 24, aperture: 1.78, shutterSpeed: "1/250", iso: 64, presets: [], filters: [], headingFromExif: true, originalFilename: "IMG_8609.HEIC", createdAt: Date()),
        Media(id: UUID(), spotId: nil, userId: UUID(), type: .photo, url: "IMG_8610", thumbnailUrl: nil, captureTimeUTC: Date(), exifData: ExifData(gpsDirection: 180), device: "iPhone 15 Pro", lens: "Main Camera", focalLengthMM: 24, aperture: 1.78, shutterSpeed: "1/200", iso: 80, presets: [], filters: [], headingFromExif: true, originalFilename: "IMG_8610.HEIC", createdAt: Date())
    ]
    
    HeadingGalleryView(media: sampleMedia)
        .padding()
}