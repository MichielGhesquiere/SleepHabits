# How to Import Synthetic Sleep Data

## Step 1: Generate the CSV file

Run the Python script to generate 3 months of realistic sleep and habit data:

```powershell
cd backend
python generate_synthetic_data.py
```

This will create `sleep_habits_export.csv` with:
- **93 sleep sessions** (July 7 - Oct 7, 2025)
- **~200+ habit checkins** with realistic patterns:
  - Weekends: later bedtimes, more alcohol
  - Good nights: meditation + reading = better scores (80-95)
  - Bad nights: alcohol + late bedtime = worse scores (50-65)

## Step 2: Import via the App

### Option A: Using the Web UI
1. Make sure backend is running (`uvicorn app.main:app --reload --port 8000`)
2. Run the Flutter app (`flutter run -d chrome`)
3. Sign in to the app
4. On the **Today** tab, click the **upload icon** (📤) in the top-right
5. Select `sleep_habits_export.csv`
6. Wait for "Import Successful!" dialog
7. Navigate to **Analytics** tab to see correlations!

### Option B: Using curl (for testing)
```bash
curl -X POST http://localhost:8000/me/import/csv \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@sleep_habits_export.csv"
```

## What You'll See

After importing, you should see:

### Dashboard (Today Tab)
- Last night's sleep score and duration
- 7-day rolling averages
- Habit completion stats

### Analytics Tab
- **Correlations** showing which habits help/hurt your sleep:
  - ✅ **Meditation**: +8 to +12 points (green, positive)
  - ✅ **Reading**: +3 to +8 points (green, positive)
  - ✅ **No screens**: +4 to +9 points (green, positive)
  - ❌ **Alcohol**: -8 to -15 points (red, negative)
  - ❌ **Late bedtime**: -5 to -10 points (orange, negative)

### Sleep Tab
- Historical sleep data
- Trends over 7/30/90 days
- Individual night details

## CSV Format

The generated CSV has this structure:

```csv
type,date,sleep_score,duration_minutes,bedtime,wake_time,habit_id,habit_name,value
sleep,2025-07-07,82,456,22:35,07:11,,,,
habit,2025-07-07,,,,,habit_reading,Reading,True
habit,2025-07-07,,,,,habit_meditation,Meditation,True
sleep,2025-07-08,68,412,23:45,06:37,,,,
habit,2025-07-08,,,,,habit_alcohol,Alcohol,True
```

## Troubleshooting

### Import fails with 404
- Check backend is running on port 8000
- Verify `/me/import/csv` endpoint exists

### No correlations showing
- Need at least 7 nights of data
- Need at least 3 nights WITH and 3 nights WITHOUT each habit
- The script generates enough data for all correlations

### Data doesn't appear
- Click refresh on the dashboard
- Check browser console for errors
- Verify you're signed in with the same user

## Customizing the Data

Edit `generate_synthetic_data.py` to change:
- **Date range**: Modify `start` and `end` dates
- **Habit patterns**: Adjust `meditation_chance`, `alcohol_chance`, etc.
- **Score impact**: Change the `base_score +=` values
- **Add new habits**: Add to the `habits` dictionary

Example:
```python
# Make meditation even more beneficial
if did_meditation:
    base_score += random.randint(10, 20)  # Instead of 5-12
```

Regenerate with:
```bash
python generate_synthetic_data.py
```

Then re-import the new CSV file!
