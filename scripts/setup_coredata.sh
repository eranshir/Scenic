#!/bin/bash

# This script creates the CoreData model structure that Xcode can import
# Run this from the Scenic project directory

echo "🚀 Setting up CoreData model structure..."

# Create the .xcdatamodeld directory
mkdir -p "ScenicDataModel.xcdatamodeld"

# Create the contents.json file
cat > "ScenicDataModel.xcdatamodeld/contents" << 'EOF'
{
  "vers" : {
    "ScenicDataModel" : {

    }
  }
}
EOF

# Move the .xcdatamodel file into the bundle
mv "ScenicDataModel.xcdatamodel" "ScenicDataModel.xcdatamodeld/"

echo "✅ CoreData model structure created!"
echo "📋 Next steps:"
echo "1. In Xcode, right-click your project"
echo "2. Choose 'Add Files to [ProjectName]'"
echo "3. Select the 'ScenicDataModel.xcdatamodeld' folder"
echo "4. Make sure 'Add to target' is checked for your main app target"
echo "5. Build the project to verify it works"
echo ""
echo "🎯 The model contains:"
echo "   - CDSpot (main entity with sync properties)"
echo "   - CDMedia (photos/videos with EXIF data)"  
echo "   - CDSunSnapshot (sun timing calculations)"
echo "   - CDWeatherSnapshot (weather conditions)"
echo "   - CDAccessInfo (parking, routes, hazards)"
echo "   - CDComment (user comments)"
echo ""
echo "All entities are configured with proper relationships and ready to use!"