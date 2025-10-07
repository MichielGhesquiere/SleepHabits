# Sleep Tab Enhancements - Summary

## What Was Added

### 1. **Enhanced Garmin Debug Logging** ✅
Added comprehensive debug logging in `backend/app/services/garmin.py` to help understand what data Garmin provides:

**What's Logged:**
- Calendar date, sleep start/end times
- Sleep duration in seconds
- Sleep stage durations (deep, light, REM, awake)
- Sleep scores (overall, quality, recovery, duration)
- Validation status
- Nap data (if available)
- All available DTO attributes

**How to View:**
Watch the backend terminal when syncing from Garmin - you'll see detailed output like:
```
[GARMIN DEBUG] Sleep data for 2025-10-07
  Calendar Date: 2025-10-07
  Sleep Start: 2025-10-06 22:30:00
  Sleep End: 2025-10-07 06:45:00
  Sleep Time (seconds): 29700
  Deep Sleep (seconds): 5940
  ...
```

### 2. **Backend Timeline Endpoint** ✅
Added `GET /me/sleep/timeline?range=week|month|year` endpoint

**Returns:**
```json
{
  "range": "week",
  "timeline": [
    {
      "date": "2025-10-01",
      "bedtime": "22:30",
      "wake_time": "06:45",
      "duration_minutes": 495,
      "sleep_score": 86,
      "stage_minutes": {
        "deep": 99,
        "light": 250,
        "rem": 105,
        "awake": 41
      }
    },
    ...
  ],
  "total_sessions": 7
}
```

### 3. **Interactive Sleep Timeline Charts** ✅
Created `sleep_timeline_chart.dart` with three beautiful charts:

#### **Chart 1: Sleep & Wake Times**
- Scatter plot showing bedtime (blue) and wake time patterns
- X-axis: Date
- Y-axis: Time of day (handles times past midnight correctly)
- Shows sleep schedule consistency at a glance

#### **Chart 2: Sleep Duration**
- Line chart with area fill
- Shows hours of sleep per night
- Curved lines for smooth visualization
- Reference grid at 2-hour intervals

#### **Chart 3: Sleep Score**
- Line chart tracking sleep quality over time
- Scale 0-100
- Green color for positive health metric
- Area fill for visual impact

### 4. **Enhanced Sleep Screen** ✅
Completely redesigned the Sleep tab with:

**Summary Cards:**
- Last Night stats (duration, score, bedtime/wake)
- 7-day Average (duration, score, midpoint, consistency)
- Sleep Stages breakdown (deep, light, REM, awake)

**Timeline Section:**
- **Range Selector**: Segmented button to choose Week/Month/Year
- **Automatic Refresh**: Provider invalidation on range change
- **Pull-to-Refresh**: Swipe down to reload all data
- **Empty States**: Helpful messages when no data exists

**UI Polish:**
- Material Design 3 styling
- Responsive layouts
- Loading indicators
- Error handling with user-friendly messages

## How to Use

### View Sleep Timeline
1. Navigate to the **Sleep** tab
2. Use the **Week/Month/Year** segmented buttons to select time range
3. Scroll down to see all three charts
4. Pull down to refresh data

### Debug Garmin Data
1. Connect your Garmin account from the Today tab
2. Click "Sync" to pull data
3. Watch the **backend terminal** for detailed debug output
4. You'll see all raw data Garmin provides (stages, scores, timestamps, etc.)

### What Data is Available from Garmin

Based on the `garminconnect` library integration:

**Sleep Metrics:**
- ✅ Sleep start/end timestamps
- ✅ Total sleep duration
- ✅ Sleep stages (deep, light, REM, awake) in seconds
- ✅ Overall sleep score (0-100)
- ✅ Sleep quality/recovery/duration scores (if available)
- ✅ Nap data (separate from main sleep)
- ✅ Validation status

**Not Currently Captured (but might be in raw data):**
- Heart rate during sleep
- Respiration rate
- Body battery/stress
- Movement/restlessness data
- Sleep insights/recommendations

**How to Explore More:**
The debug logging now prints `dir(dto)` which shows ALL available attributes. Check the terminal output when syncing to see what else Garmin provides that we could use!

## Chart Features

### Bedtime/Wake Time Chart
- **Handles late bedtimes**: Times past midnight shown correctly (24+ hours)
- **Date labels**: Shows M/d format on X-axis
- **Time labels**: HH:00 format on Y-axis
- **Interval adjustment**: Automatically adjusts based on range (week=daily, month=every 3 days, year=weekly)

### Duration Chart
- **Smooth curves**: isCurved=true for better visual flow
- **Area fill**: Blue gradient below line for emphasis
- **Target zones**: Can easily add reference lines (e.g., 7-9 hour target)

### Score Chart
- **Health metric**: Green color indicates positive metric
- **0-100 scale**: Standard sleep score range
- **Trend visibility**: Easy to spot improving/declining patterns

## Technical Details

### Dependencies Added
- `fl_chart: ^0.69.0` - Professional charting library

### New Files
- `app/lib/features/sleep/sleep_timeline_chart.dart` - Reusable chart widget
- `SLEEP_ENHANCEMENTS.md` - This documentation

### Modified Files
- `backend/app/services/garmin.py` - Added debug logging
- `backend/app/services/sleep.py` - Added `get_timeline()` method
- `backend/app/routers/me.py` - Added `/me/sleep/timeline` endpoint
- `app/lib/features/sleep/sleep_repository.dart` - Added `fetchTimeline()` method
- `app/lib/features/sleep/sleep_screen.dart` - Complete redesign with charts
- `app/pubspec.yaml` - Added fl_chart dependency

### State Management
- `timelineRangeProvider` - Tracks selected range (week/month/year)
- `sleepTimelineProvider` - Fetches timeline data when range changes
- Auto-invalidation on range change for seamless UX

## Future Enhancements

### Chart Improvements
- [ ] Add tooltips on hover/tap showing exact values
- [ ] Add zoom/pan gestures for long timelines
- [ ] Add reference lines (target sleep duration, optimal bedtime)
- [ ] Compare periods (this week vs last week)

### Data Insights
- [ ] Detect patterns (e.g., "You sleep better on weekends")
- [ ] Show correlations with habits on charts
- [ ] Highlight anomalies (unusually good/bad nights)
- [ ] Add sleep debt calculation

### Additional Charts
- [ ] Sleep stages as stacked area chart
- [ ] Week heatmap (color-coded by score)
- [ ] Circadian rhythm visualization (sleep window)
- [ ] Consistency score trend

### Export/Share
- [ ] Export charts as images
- [ ] Generate PDF sleep reports
- [ ] Share insights to social media

## Testing Checklist

- [x] Week range shows last 7 days correctly
- [x] Month range shows last 30 days
- [x] Year range shows last 365 days
- [x] Charts render with imported CSV data
- [x] Charts update when range changes
- [x] Empty state shows helpful message
- [x] Loading states work correctly
- [x] Pull-to-refresh updates all data
- [x] Debug logging appears in terminal
- [x] Bedtime chart handles times past midnight
- [x] All three charts render side by side

## Garmin Data Available

Based on the `SleepData` class from `garth`:

```python
dto.calendar_date          # Date of sleep
dto.sleep_start           # Start datetime
dto.sleep_end             # End datetime
dto.sleep_time_seconds    # Total sleep duration
dto.deep_sleep_seconds    # Deep sleep stage
dto.light_sleep_seconds   # Light sleep stage
dto.rem_sleep_seconds     # REM sleep stage
dto.awake_sleep_seconds   # Awake time
dto.sleep_scores.overall.value           # Overall score
dto.sleep_scores.quality_score           # Quality component
dto.sleep_scores.recovery_score          # Recovery component
dto.sleep_scores.duration_score          # Duration component
dto.validation            # Data quality/validation
data.naps                 # Nap data (separate)
```

Check the backend terminal output for the full list of available attributes!

---

**Status:** ✅ **Fully Implemented** - Sleep tab now has comprehensive visualization with week/month/year views and detailed Garmin debug logging!
