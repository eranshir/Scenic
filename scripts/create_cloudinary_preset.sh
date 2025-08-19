#!/bin/bash

# Create Cloudinary Upload Preset via API
# Replace API_SECRET with your actual Cloudinary API Secret

CLOUD_NAME="scenic-app"
API_KEY="398184757632917"
API_SECRET="YOUR_API_SECRET_HERE"  # Add your API secret

echo "Creating Cloudinary upload preset..."

curl -X POST \
  "https://api.cloudinary.com/v1_1/${CLOUD_NAME}/upload_presets" \
  -u "${API_KEY}:${API_SECRET}" \
  -d '{
    "name": "scenic_mobile_auto",
    "unsigned": true,
    "folder": "scenic/spots",
    "allowed_formats": ["jpg", "jpeg", "png", "heic", "heif", "webp", "mp4", "mov"],
    "max_file_size": 52428800,
    "tags": ["scenic", "mobile"],
    "eager": [
      {
        "width": 150,
        "height": 150,
        "crop": "thumb",
        "gravity": "auto",
        "quality": "auto",
        "format": "auto"
      },
      {
        "width": 400,
        "height": 300,
        "crop": "fill",
        "gravity": "auto",
        "quality": "auto"
      },
      {
        "quality": "auto",
        "format": "auto",
        "flags": ["progressive", "immutable_cache"],
        "fetch_format": "auto"
      }
    ],
    "eager_async": true,
    "auto_tagging": 30,
    "categorization": ["google_tagging", "aws_rek_tagging"],
    "return_delete_token": true,
    "overwrite": false,
    "unique_filename": true,
    "faces": true,
    "colors": true,
    "image_metadata": true,
    "phash": true,
    "use_filename": true,
    "notification_url": ""
  }' | python3 -m json.tool

echo "Done! Check the response above for the preset details."