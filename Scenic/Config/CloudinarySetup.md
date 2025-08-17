# Cloudinary Setup Instructions

## 1. Login to Cloudinary Dashboard
Go to: https://console.cloudinary.com/

## 2. Create Upload Preset
1. Go to **Settings** (gear icon)
2. Click **Upload** tab
3. Scroll to **Upload presets**
4. Click **Add upload preset**
5. Configure as follows:

### Preset Name: `scenic_mobile`
- **Signing Mode**: Unsigned (for now, we'll add signing later)
- **Folder**: `scenic/spots`
- **Allowed formats**: jpg, jpeg, png, heic, heif, webp, mp4, mov
- **Max file size**: 50 MB
- **Tags**: Add `scenic`, `mobile`

### Eager Transformations (auto-generate these versions):
1. **Thumbnail**: 
   - Width: 150, Height: 150
   - Crop: thumb
   - Gravity: auto
   - Quality: auto

2. **Card**: 
   - Width: 400, Height: 300
   - Crop: fill
   - Gravity: auto
   - Quality: auto

3. **Optimized**:
   - Format: auto
   - Quality: auto
   - DPR: auto

### Upload Control:
- ✅ Return delete token
- ✅ Overwrite
- ✅ Unique filename
- ✅ Async

Click **Save**

## 3. Create API Credentials File

Cloud Name: scenic-app
API Key: 398184757632917
API Secret: [Keep this safe - don't share]

## 4. Configure Auto-tagging (Optional)
1. Go to **Add-ons**
2. Enable **Cloudinary AI Content Analysis**
3. Enable **AWS Rekognition Auto Tagging** (for content moderation)

## 5. Set Upload Limits
1. Go to **Security**
2. Set rate limits:
   - Max uploads per hour: 100 per IP
   - Max file size: 50MB