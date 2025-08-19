# Scenic 📸

> **A crowdsourced photography platform for discovering optimal photo locations**

Scenic helps photographers discover the best locations and timing for landscape photography through crowdsourced data, enhanced metadata, and precise solar calculations.

![Version](https://img.shields.io/badge/version-v0.1.2-blue)
![iOS](https://img.shields.io/badge/iOS-17+-brightgreen)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

---

## ✨ Features

- **📍 GPS-Based Discovery**: Find scenic photo locations with precise coordinates
- **☀️ Optimal Timing**: Sun position calculations for golden hour and blue hour
- **🏷️ Rich Metadata**: Camera settings, EXIF data, and photographer attribution  
- **🗺️ Interactive Maps**: Clustering and proximity-based location grouping
- **📱 Native iOS**: SwiftUI + Core Data with offline caching
- **☁️ Cloud Backend**: Supabase + PostGIS with Cloudinary media storage

## 🚀 Quick Start

### Prerequisites

- **iOS Development**: Xcode 15+, iOS 17+ deployment target
- **Backend Services**: Supabase account, Cloudinary account
- **Photo Import** (optional): Node.js 20+ for bulk import tools

### Setup

1. **Clone & Install**
   ```bash
   git clone https://github.com/eranshir/Scenic.git
   cd Scenic
   open Scenic.xcodeproj
   ```

2. **Configure Backend**
   - See [Authentication Setup Guide](Scenic/documents/Scenic_Authentication_Setup_Guide.md)
   - Run database migrations from `/Scenic/Config/` 

3. **Build & Run**
   - Update team signing in Xcode
   - Build for iOS Simulator or device
   - App supports guest mode for immediate exploration

## 📚 Documentation

### 🎯 Quick Access
- **⭐ [Data Import & Operations Guide](Scenic/documents/Scenic_Data_Import_Operations.md)** - Import procedures & scripts
- **🔧 [Scripts Reference Guide](scripts/SCRIPTS_REFERENCE.md)** - Complete script documentation & usage
- **📋 [Import Script Setup](scripts/README_IMPORT.md)** - Flickr bulk import instructions  
- **🔑 [Authentication Setup](Scenic/documents/Scenic_Authentication_Setup_Guide.md)** - Backend configuration

### 📋 Full Documentation Index
- [Product Requirements (PRD)](Scenic/documents/Scenic_PRD.md)
- [Technical Architecture](Scenic/documents/Scenic_ADR_Architecture.md) 
- [Database Schema](Scenic/documents/Scenic_Database_Schema.md)
- [**Complete Documentation Index →**](Scenic/documents/Scenic_Doc_Index.md)

## 🛠️ Data Import System

Scenic includes a powerful bulk import system for photo collections:

### Flickr Import (Ready to Use)

```bash
cd scripts
npm install

# Test import
node flickr-bulk-import.js --dry-run --max-photos=5

# Full import
node flickr-bulk-import.js
```

**Features:**
- ✅ Database-aware duplicate prevention
- 📊 Smart proximity grouping (100m threshold)  
- ⚡ Configurable performance options
- 🎯 Complete metadata preservation
- 📱 iOS app auto-sync integration

**See:** [Complete Import Guide →](Scenic/documents/Scenic_Data_Import_Operations.md)

## 🏗️ Architecture

### iOS App Stack
- **UI**: SwiftUI with UIKit interop for camera/photos
- **Data**: Core Data + CloudKit sync
- **Maps**: MapKit with custom overlays and clustering  
- **Images**: AsyncImage with comprehensive caching system
- **Authentication**: Sign in with Apple + Guest mode

### Backend Stack  
- **Database**: PostgreSQL with PostGIS (geospatial)
- **API**: Supabase with Row Level Security
- **Storage**: Cloudinary with optimized transformations
- **Import**: Node.js scripts with rate limiting

### Data Flow
```
Flickr Photos → Import Script → Supabase → iOS Sync → Core Data → SwiftUI
```

## 📦 Project Structure

```
Scenic/
├── Scenic/                     # iOS App
│   ├── Views/                  # SwiftUI views
│   ├── Models/                 # Core Data models  
│   ├── Services/               # Data services
│   └── documents/              # Documentation
├── scripts/                    # Import tools
│   ├── flickr-bulk-import.js   # Main import script
│   ├── cleanup-*.js           # Maintenance utilities
│   └── README_IMPORT.md        # Import guide
└── Config/                     # Database schemas
    └── supabase_schema_*.sql
```

## 🚦 Current Status (v0.1.2)

### ✅ Completed
- **Core iOS App**: Photo discovery, detail views, caching system
- **Backend Integration**: Supabase sync with enhanced metadata
- **Import Pipeline**: 334 GPS-enabled Flickr photos successfully imported
- **Data Architecture**: Resolved circular GPS coordinate issues
- **Attribution System**: Proper photographer credits and licensing

### 🔄 In Progress
- Performance optimization for large datasets
- Advanced filtering and search capabilities
- Social features (voting, comments)

### 🎯 Roadmap
- **Camera Integration**: In-app capture with automatic metadata
- **Route Planning**: Multi-location itineraries with optimal timing
- **Weather Integration**: Historical and forecast data
- **Community Features**: User profiles, following, spot recommendations

## 🤝 Contributing

This is a personal project, but contributions and suggestions are welcome:

1. **Issues**: Report bugs or request features via GitHub issues
2. **Documentation**: Help improve setup guides and documentation
3. **Testing**: Try the import system with different photo collections
4. **Ideas**: Share thoughts on new features or improvements

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Flickr Community**: Photography data and inspiration
- **Apple**: SwiftUI, MapKit, and development tools  
- **Supabase**: Backend-as-a-service platform
- **Cloudinary**: Media optimization and delivery

---

**Latest Update:** Enhanced import system with database-aware duplicate prevention (v0.1.2)  
**Next Milestone:** Advanced search and filtering capabilities

*Built with ❤️ for the photography community*