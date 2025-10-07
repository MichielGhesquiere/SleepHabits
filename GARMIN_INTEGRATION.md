# Garmin Integration Guide

## Features Implemented

### 1. **Garmin Connect Screen** (`garmin_connect_screen.dart`)
- Email/password form with validation
- Password visibility toggle
- Multi-Factor Authentication (MFA) support with dialog
- Loading states and error handling
- Security & privacy notice
- Success confirmation dialog

### 2. **Dashboard Integration** (`dashboard_screen.dart`)
- **Not Connected State**: Shows "Connect to Garmin" card with call-to-action
- **Connected State**: Shows "Garmin Connected" status with "Sync" button
- Automatic detection of Garmin connection status from API
- Manual sync button to pull latest sleep data

### 3. **Backend Endpoints** (already implemented)
- `POST /garmin/connect` - Connect with credentials (handles MFA)
- `POST /garmin/pull` - Pull latest sleep data (30 days by default)

## How to Use

### Option 1: Connect with Real Garmin Credentials

1. Open the app in your browser
2. Sign in with your email
3. On the Dashboard, you'll see a "Connect to Garmin" card
4. Click on it to navigate to the Garmin Connect screen
5. Enter your **Garmin Connect** email and password
6. Click "Connect to Garmin"
7. If MFA is enabled on your account:
   - A dialog will appear asking for the verification code
   - Check your email/SMS for the Garmin MFA code
   - Enter the code and click "Verify"
8. Once connected, you'll see a success message
9. The dashboard will show "Garmin Connected" status
10. Click "Sync" to pull your latest sleep data

### Option 2: Test with Sample/Demo Mode

The backend has a **demo mode** enabled by default (`GARMIN_SAMPLE_MODE=1`):

- If Garmin login fails (wrong credentials, rate limit, network error), it automatically loads sample data from `backend/app/data/sample_garmin_sleep.json`
- This allows testing the full flow without real Garmin credentials

**To test demo mode:**
1. Use any fake email/password (e.g., `test@example.com` / `wrongpassword`)
2. The backend will catch the authentication error and load sample data
3. You'll see the success message and data will appear in the dashboard

### Option 3: Manual Entry (Existing)

- Click the floating action button "+ Add Sleep Entry"
- Fill in date, score, bedtime, wake time, duration, and habits
- Save to add a manual entry

### Option 4: CSV Upload (Existing)

- Click the upload icon in the app bar
- Select `backend/sleep_habits_export.csv` (93 days of synthetic data)
- Import completes with success message

## User Flow

```
Dashboard (Not Connected)
    ↓
[Connect to Garmin] Card
    ↓
Garmin Connect Screen
    ↓
Enter Email/Password
    ↓
    ├─→ [If MFA Required]
    │       ↓
    │   MFA Dialog
    │       ↓
    │   Enter Code
    │       ↓
    └─→ [Success]
        ↓
    Dashboard (Connected)
        ↓
    [Sync] Button to refresh data
```

## Backend Configuration

### Environment Variables

```bash
# Enable sample data fallback when Garmin login fails
GARMIN_SAMPLE_MODE=1  # Default: enabled

# To disable fallback (production):
GARMIN_SAMPLE_MODE=0
```

### Sample Data Location

`backend/app/data/sample_garmin_sleep.json` - Contains sample sleep sessions for demo/testing

### Token Storage

Garmin OAuth tokens are stored in: `backend/app/data/garmin_tokens/{user_id}/`

**Note:** These are stored in-memory with the current setup and will be lost on server restart.

## Testing Checklist

- [ ] Dashboard shows "Connect to Garmin" card when not connected
- [ ] Clicking card navigates to Garmin Connect screen
- [ ] Email validation works (requires @ symbol)
- [ ] Password validation works (required field)
- [ ] Password visibility toggle works
- [ ] Invalid credentials show error message (or trigger demo mode)
- [ ] MFA dialog appears if required
- [ ] MFA code verification works
- [ ] Success dialog appears after connection
- [ ] Dashboard shows "Garmin Connected" status after success
- [ ] "Sync" button pulls latest data
- [ ] Success/error messages appear for sync operations
- [ ] Data refreshes after successful sync

## Known Limitations

1. **In-Memory Storage**: Garmin tokens and session data are lost on server restart
2. **Credential-Based Auth**: Uses Garmin Connect credentials (not official OAuth2 API)
3. **Rate Limiting**: Garmin may rate-limit requests; demo mode activates as fallback
4. **No Official Partnership**: This uses the community `garminconnect` library, not the official Garmin Health API

## Future Enhancements

According to `AGENTS.md`, the ideal implementation would use:

- **Garmin Health API** with OAuth2 PKCE flow (requires Garmin partnership)
- **Webhooks** for automatic data push
- **Database persistence** for tokens and sessions
- **HealthKit (iOS)** and **Health Connect (Android)** as device-side fallbacks

## Troubleshooting

### "Connection failed" error
- Check that the backend is running (`uvicorn app.main:app --reload`)
- Verify credentials are correct
- If demo mode is enabled, it should fall back to sample data automatically

### MFA dialog doesn't appear
- Check that your Garmin account has MFA enabled
- The backend should return `mfa_required: true` in the response

### Sync button does nothing
- Check browser console for errors
- Verify `garmin_connected` is `true` in the API response
- Check backend logs for Garmin API errors

### Data disappears after server restart
- This is expected with in-memory storage
- Re-connect to Garmin or re-upload CSV to restore data

## Architecture Overview

```
Flutter App
    ↓
GarminRepository (API client)
    ↓
FastAPI Backend
    ↓
GarminConnectService
    ↓
garminconnect library (Python)
    ↓
Garmin Connect API (unofficial)
```

## Security Notes

- Credentials are sent over HTTPS to the backend
- Tokens are stored server-side (not in browser)
- Password is never logged or displayed in plain text
- Users are shown a security notice before connecting
- Credentials are only used to authenticate with Garmin, never shared with third parties

---

**Status:** ✅ **Fully Implemented** - All three data entry methods are now available:
1. ✅ Garmin Connect (with MFA)
2. ✅ Manual Entry
3. ✅ CSV Upload
