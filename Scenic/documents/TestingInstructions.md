# Backend Services Testing Instructions

## How to Access Test Menu

1. **Run the app** in Xcode simulator or on device
2. **Navigate to Home View** (Discover tab)
3. **Look for the orange hammer icon** (🔨) in the top-left navigation bar (only visible in DEBUG mode)
4. **Tap the hammer icon** to open the Backend Service Test View

## Test Menu Features

### Available Test Categories:
- **SpotService**: Create, fetch, update, and delete spots
- **MediaService**: Upload images, manage media, test Cloudinary integration
- **PlanService**: Create plans, add spots to plans, manage itineraries
- **Integration**: End-to-end workflows that test multiple services together

### Test Interface:
- **Test Buttons**: Each test has its own button - tap to run
- **Progress Indicator**: Shows when a test is running
- **Test Log**: Bottom section shows real-time test results
  - ✅ Green = Success
  - ❌ Red = Error
  - ℹ️ Blue = Info
- **Clear Button**: Clears the test log

## Recommended Test Sequence

### Quick Validation (5 minutes):
1. **SpotService** → "Create Basic Spot"
2. **SpotService** → "Fetch All Spots"
3. **MediaService** → "Upload Test Image"
4. **PlanService** → "Create Plan"
5. **Integration** → "Complete Spot Creation Flow"

### Comprehensive Testing (15 minutes):
Run tests in each category sequentially, starting with:
1. All **SpotService** tests
2. All **MediaService** tests (grant photo access when prompted)
3. All **PlanService** tests
4. All **Integration** tests

## What to Look For

### Success Indicators:
- Test log shows green checkmarks
- No red error messages
- Created items have valid IDs
- Upload progress reaches 100%
- Fetched data matches what was created

### Common Issues:
- **Auth errors**: Make sure you're signed in (Apple/Google/Guest)
- **Network errors**: Check internet connection
- **Photo access**: Grant permission when prompted
- **Cloudinary errors**: Check API keys in CloudinaryManager

## Test Data Cleanup

After testing, you can clean up test data in Supabase:
1. Go to your Supabase dashboard
2. Navigate to SQL Editor
3. Run the cleanup script from TestPlan_BackendServices.md

## Troubleshooting

- **Tests not appearing**: Make sure you're running in DEBUG configuration
- **Upload failures**: Check Cloudinary dashboard for quota/limits
- **Database errors**: Check Supabase logs for detailed error messages
- **Missing hammer icon**: Rebuild project in Xcode

## Notes

- Test data is created with "Test" prefix for easy identification
- Each test run creates unique items with timestamps
- Some tests depend on previously created items (IDs are preserved in session)
- Tests run with real backend services - data will persist in database