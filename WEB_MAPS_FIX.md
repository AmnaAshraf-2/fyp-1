# Google Maps Web Fix Guide

## Issues Fixed:

1. **Added Required Libraries to web/index.html**
   - Added `directions`, `geometry`, and `drawing` libraries to Google Maps script
   - These are needed for route rendering and directions on web

2. **Web-Specific Map Configuration**
   - Disabled `myLocationButtonEnabled` and `myLocationEnabled` on web (requires HTTPS)
   - Added web-specific polyline properties for better rendering
   - Adjusted padding for bounds fitting on web

## Additional Steps Required:

### 1. Enable APIs in Google Cloud Console
Make sure these APIs are enabled for your API key:
- Maps JavaScript API ✅ (already enabled)
- Places API ✅ (already enabled)
- Directions API ⚠️ (needs to be enabled)
- Routes API ⚠️ (needs to be enabled - for new Directions API)

### 2. API Key Restrictions
If your API key has restrictions, make sure:
- HTTP referrers include your domain (e.g., `localhost:*, yourdomain.com/*`)
- Or use unrestricted for development

### 3. Run on HTTPS (for location services)
For location services to work on web:
- Use `flutter run -d chrome --web-port=8080` with HTTPS
- Or deploy to a server with HTTPS

### 4. Test the Fix
1. Run: `flutter run -d chrome`
2. Navigate to a route/map screen
3. Check browser console for any errors
4. Verify polylines are rendering

## Common Issues:

### Polylines not showing:
- Check browser console for JavaScript errors
- Verify Directions API is enabled
- Check API key permissions

### Location not working:
- Location services require HTTPS on web
- User must grant location permissions
- Check browser console for permission errors

### Maps not loading:
- Verify API key is correct
- Check API key restrictions
- Ensure Maps JavaScript API is enabled

