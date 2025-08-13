import SwiftUI
import PhotosUI
import Photos

struct AddSpotView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedMedia: [PhotosPickerItem] = []
    @State private var extractedMetadata: [ExtractedPhotoMetadata] = []
    @State private var currentStep = AddSpotStep.selectMedia
    @State private var spotData = NewSpotData()
    @StateObject private var metadataExtractor = PhotoMetadataExtractor()
    
    enum AddSpotStep {
        case selectMedia
        case confirmMetadata
        case addRoute
        case publish
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                
                Group {
                    switch currentStep {
                    case .selectMedia:
                        MediaPickerStep(
                            selectedMedia: $selectedMedia,
                            onNext: {
                                Task {
                                    await extractMetadata()
                                    currentStep = .confirmMetadata
                                }
                            }
                        )
                    case .confirmMetadata:
                        MetadataConfirmStep(
                            spotData: $spotData,
                            extractedMetadata: extractedMetadata,
                            onNext: {
                                currentStep = .addRoute
                            },
                            onBack: {
                                currentStep = .selectMedia
                            }
                        )
                    case .addRoute:
                        RouteStep(
                            spotData: $spotData,
                            onNext: {
                                currentStep = .publish
                            },
                            onBack: {
                                currentStep = .confirmMetadata
                            }
                        )
                    case .publish:
                        PublishStep(
                            spotData: $spotData,
                            onPublish: {
                                // Handle publish
                            },
                            onBack: {
                                currentStep = .addRoute
                            }
                        )
                    }
                }
            }
            .navigationTitle("Add Spot")
            .navigationBarTitleDisplayMode(.inline)
            // Add safe area padding to account for tab bar
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 0)
            }
        }
    }
    
    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach([AddSpotStep.selectMedia, .confirmMetadata, .addRoute, .publish], id: \.self) { step in
                Rectangle()
                    .fill(stepColor(for: step))
                    .frame(height: 3)
                    .animation(.easeInOut, value: currentStep)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private func stepColor(for step: AddSpotStep) -> Color {
        let steps: [AddSpotStep] = [.selectMedia, .confirmMetadata, .addRoute, .publish]
        let currentIndex = steps.firstIndex(of: currentStep) ?? 0
        let stepIndex = steps.firstIndex(of: step) ?? 0
        
        return stepIndex <= currentIndex ? Color.green : Color(.systemGray5)
    }
    
    private func extractMetadata() async {
        extractedMetadata = []
        for item in selectedMedia {
            do {
                let metadata = try await metadataExtractor.extractMetadata(from: item)
                extractedMetadata.append(metadata)
                
                // Update spot data with first media's location and metadata
                if extractedMetadata.count == 1 {
                    spotData.location = metadata.location
                    spotData.heading = metadata.heading.map { Int($0) }
                    spotData.elevation = metadata.altitude.map { Int($0) }
                    spotData.captureDate = metadata.captureDate
                    spotData.cameraMake = metadata.cameraMake
                    spotData.cameraModel = metadata.cameraModel
                    spotData.lensModel = metadata.lensModel
                }
            } catch {
                print("Failed to extract metadata: \(error)")
            }
        }
    }
}

struct NewSpotData {
    var title = ""
    var location: CLLocationCoordinate2D?
    var heading: Int?
    var elevation: Int?
    var tags: [String] = []
    var difficulty: Spot.Difficulty = .moderate
    var notes = ""
    var parkingLocation: CLLocationCoordinate2D?
    var routePolyline: String?
    var hazards: [String] = []
    var fees: [String] = []
    
    // Photography metadata
    var captureDate: Date?
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var focalLength: Float?
    var focalLengthIn35mm: Float?
    var aperture: Float?
    var shutterSpeed: String?
    var iso: Int?
    var exposureBias: Float?
    var meteringMode: String?
    var whiteBalance: String?
    var flash: Bool = false
    
    // Post-processing
    var software: String?
    var presets: [String] = []
    var filters: [String] = []
    var editingNotes: String = ""
    
    // Tips for photographers
    var bestTimeNotes: String = ""
    var equipmentTips: String = ""
    var compositionTips: String = ""
    var seasonalNotes: String = ""
}

struct MediaPickerStep: View {
    @Binding var selectedMedia: [PhotosPickerItem]
    let onNext: () -> Void
    @State private var mediaType: MediaSelectionType = .both
    
    enum MediaSelectionType {
        case photos, videos, both
        
        var filter: PHPickerFilter {
            switch self {
            case .photos: return .images
            case .videos: return .videos
            case .both: return .any(of: [.images, .videos])
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Select Media")
                        .font(.title2)
                        .bold()
                        .padding(.top)
                    
                    Text("Choose photos or videos that showcase this spot")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Picker("Media Type", selection: $mediaType) {
                        Text("Photos").tag(MediaSelectionType.photos)
                        Text("Videos").tag(MediaSelectionType.videos)
                        Text("Both").tag(MediaSelectionType.both)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    PhotosPicker(
                        selection: $selectedMedia,
                        maxSelectionCount: 10,
                        matching: mediaType.filter
                    ) {
                        VStack(spacing: 12) {
                            HStack(spacing: 20) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 40))
                                Image(systemName: "video.fill")
                                    .font(.system(size: 40))
                            }
                            .foregroundColor(.green)
                            
                            Text("Tap to Select Media")
                                .font(.headline)
                            
                            if !selectedMedia.isEmpty {
                                Text("\(selectedMedia.count) items selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("EXIF data will be extracted automatically", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("Supports RAW, HEIC, JPEG, and video formats", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            
            Button(action: onNext) {
                HStack {
                    if selectedMedia.isEmpty {
                        Text("Select Media to Continue")
                    } else {
                        Text("Extract Metadata")
                        Image(systemName: "arrow.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedMedia.isEmpty ? Color.gray : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(selectedMedia.isEmpty)
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

#Preview {
    AddSpotView()
        .environmentObject(AppState())
}