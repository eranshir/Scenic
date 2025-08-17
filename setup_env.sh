#!/bin/bash

# Scenic Environment Setup Script
# This script helps set up and validate environment variables

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_FILE="$SCRIPT_DIR/.env.local"
ENV_TEMPLATE="$SCRIPT_DIR/.env.local"

echo "🔧 Scenic Environment Setup"
echo "=========================="

# Check if .env.local exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env.local file not found!"
    echo "Creating from template..."
    cp "$ENV_TEMPLATE" "$ENV_FILE"
    echo "✅ Created .env.local - Please fill in your credentials"
    exit 1
fi

# Function to check if a variable is set
check_var() {
    local var_name=$1
    local var_value=$(grep "^$var_name=" "$ENV_FILE" | cut -d'=' -f2)
    
    if [[ -z "$var_value" ]] || [[ "$var_value" == *"your_"* ]] || [[ "$var_value" == *"_here"* ]]; then
        echo "❌ $var_name is not configured"
        return 1
    else
        echo "✅ $var_name is set"
        return 0
    fi
}

echo ""
echo "Checking required variables..."
echo "------------------------------"

# Required variables
REQUIRED_VARS=(
    "SUPABASE_URL"
    "SUPABASE_ANON_KEY"
    "CLOUDINARY_CLOUD_NAME"
    "CLOUDINARY_API_KEY"
)

ALL_GOOD=true

for var in "${REQUIRED_VARS[@]}"; do
    if ! check_var "$var"; then
        ALL_GOOD=false
    fi
done

echo ""
echo "Checking optional variables..."
echo "------------------------------"

# Optional but recommended
OPTIONAL_VARS=(
    "SUPABASE_SERVICE_KEY"
    "CLOUDINARY_API_SECRET"
    "APPLE_TEAM_ID"
    "OPENAI_API_KEY"
)

for var in "${OPTIONAL_VARS[@]}"; do
    check_var "$var" || true
done

echo ""
echo "Checking feature flags..."
echo "------------------------"

# Feature flags
FEATURE_FLAGS=(
    "ENABLE_OFFLINE_MODE"
    "ENABLE_SOCIAL_FEATURES"
    "ENABLE_PLANNING_FEATURES"
    "ENABLE_PAYMENT_FEATURES"
)

for flag in "${FEATURE_FLAGS[@]}"; do
    flag_value=$(grep "^$flag=" "$ENV_FILE" | cut -d'=' -f2)
    echo "📋 $flag = $flag_value"
done

# Create Info.plist entries for production
echo ""
echo "Generating Info.plist configuration..."
echo "--------------------------------------"

cat > "$SCRIPT_DIR/Scenic/Info.plist.additions" << EOF
<!-- Add these to your Info.plist for production builds -->
<key>SupabaseURL</key>
<string>\$(SUPABASE_URL)</string>
<key>SupabaseAnonKey</key>
<string>\$(SUPABASE_ANON_KEY)</string>
<key>CloudinaryCloudName</key>
<string>\$(CLOUDINARY_CLOUD_NAME)</string>
<key>CloudinaryAPIKey</key>
<string>\$(CLOUDINARY_API_KEY)</string>
EOF

echo "✅ Created Info.plist.additions"

# Summary
echo ""
echo "======================================"
if [ "$ALL_GOOD" = true ]; then
    echo "✅ Environment is properly configured!"
else
    echo "⚠️  Some required variables are missing"
    echo "Please edit .env.local and add the missing values"
fi
echo "======================================"

# Offer to test connections
echo ""
read -p "Would you like to test the connections? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Testing Supabase connection..."
    SUPABASE_URL=$(grep "^SUPABASE_URL=" "$ENV_FILE" | cut -d'=' -f2)
    if curl -s "$SUPABASE_URL/rest/v1/" > /dev/null; then
        echo "✅ Supabase is reachable"
    else
        echo "❌ Cannot reach Supabase"
    fi
    
    echo "Testing Cloudinary..."
    CLOUD_NAME=$(grep "^CLOUDINARY_CLOUD_NAME=" "$ENV_FILE" | cut -d'=' -f2)
    if curl -s "https://res.cloudinary.com/$CLOUD_NAME/image/upload/sample.jpg" > /dev/null; then
        echo "✅ Cloudinary is configured"
    else
        echo "❌ Cloudinary might not be configured correctly"
    fi
fi

echo ""
echo "Done! 🎉"