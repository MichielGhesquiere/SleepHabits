"""
Generate realistic synthetic sleep and habit data for testing.

Creates 3 months of data (July 7 - Oct 7, 2025) with realistic patterns:
- Weekends: tend to sleep later, more alcohol
- Good nights: meditation, reading, no alcohol → better sleep scores
- Bad nights: late bedtime, alcohol, screens → worse sleep scores
- Some random variation for realism

Output: sleep_habits_export.csv
"""

import csv
import random
from datetime import date, timedelta
from typing import List, Dict, Any


def generate_realistic_sleep_data(start_date: date, end_date: date) -> List[Dict[str, Any]]:
    """Generate realistic sleep sessions with correlated habits."""
    
    data = []
    current_date = start_date
    
    # Habit IDs (matching the default habits from the system)
    habits = {
        'reading': 'habit-read',
        'meditation': 'habit-meditate',
        'no_screens': 'habit-no-screens',
        'alcohol': 'habit-alcohol',
        'consistent_bedtime': 'habit-consistent-bedtime',
    }
    
    while current_date <= end_date:
        is_weekend = current_date.weekday() >= 5  # Saturday=5, Sunday=6
        
        # Base patterns
        if is_weekend:
            # Weekends: more likely to stay up late, drink alcohol
            base_bedtime_hour = random.choice([23, 0, 1])  # 11pm, midnight, 1am
            alcohol_chance = 0.6
            meditation_chance = 0.2
            reading_chance = 0.4
        else:
            # Weekdays: more consistent bedtime
            base_bedtime_hour = random.randint(22, 23)  # 10pm - 11pm
            alcohol_chance = 0.2
            meditation_chance = 0.5
            reading_chance = 0.6
        
        # Determine habits for tonight
        did_reading = random.random() < reading_chance
        did_meditation = random.random() < meditation_chance
        did_alcohol = random.random() < alcohol_chance
        # If drinking, how many drinks? (1-4)
        alcohol_count = random.randint(1, 4) if did_alcohol else 0
        did_no_screens = random.random() < (0.7 if did_meditation else 0.3)
        
        # Consistent bedtime if went to bed around the same time
        bedtime_hour = base_bedtime_hour + random.randint(-1, 1)
        # Normalize to 0-23 range (handle wraparound)
        while bedtime_hour >= 24:
            bedtime_hour -= 24
        while bedtime_hour < 0:
            bedtime_hour += 24
            
        did_consistent_bedtime = 22 <= bedtime_hour <= 23
        
        bedtime_minute = random.randint(0, 59)
        bedtime = f"{bedtime_hour:02d}:{bedtime_minute:02d}"
        
        # Calculate sleep quality based on habits
        base_score = 70
        
        # Positive habits increase score
        if did_reading:
            base_score += random.randint(3, 8)
        if did_meditation:
            base_score += random.randint(5, 12)
        if did_no_screens:
            base_score += random.randint(4, 9)
        if did_consistent_bedtime:
            base_score += random.randint(2, 6)
        
        # Negative habits decrease score
        if did_alcohol:
            # More drinks = worse sleep
            base_score -= random.randint(8, 15) + (alcohol_count - 1) * 3
        if bedtime_hour >= 0 and bedtime_hour < 2:  # Very late bedtime
            base_score -= random.randint(5, 10)
        
        # Add some random variation
        base_score += random.randint(-5, 5)
        
        # Clamp score to 0-100
        sleep_score = max(40, min(100, base_score))
        
        # Duration correlates with score
        if sleep_score >= 80:
            duration_hours = random.uniform(7.5, 9.0)
        elif sleep_score >= 65:
            duration_hours = random.uniform(6.5, 8.0)
        else:
            duration_hours = random.uniform(5.5, 7.0)
        
        duration_minutes = int(duration_hours * 60)
        
        # Calculate wake time (handle day wraparound)
        total_minutes = bedtime_hour * 60 + bedtime_minute + duration_minutes
        wake_hour = (total_minutes // 60) % 24
        wake_minute = total_minutes % 60
        wake_time = f"{wake_hour:02d}:{wake_minute:02d}"
        
        # Add sleep entry
        data.append({
            'type': 'sleep',
            'date': current_date.isoformat(),
            'sleep_score': sleep_score,
            'duration_minutes': duration_minutes,
            'bedtime': bedtime,
            'wake_time': wake_time,
        })
        
        # Add habit checkins
        if did_reading:
            data.append({
                'type': 'habit',
                'date': current_date.isoformat(),
                'habit_id': habits['reading'],
                'habit_name': 'Read ≥15 minutes',
                'value': True,
            })
        
        if did_meditation:
            data.append({
                'type': 'habit',
                'date': current_date.isoformat(),
                'habit_id': habits['meditation'],
                'habit_name': 'Meditate ≥10 minutes',
                'value': True,
            })
        
        # Track alcohol consumption (unhealthy habit)
        # Always log it - 0 if no alcohol, count if consumed
        if did_alcohol:
            data.append({
                'type': 'habit',
                'date': current_date.isoformat(),
                'habit_id': habits['alcohol'],
                'habit_name': 'Consumed alcohol',
                'value': alcohol_count,  # Number of drinks
            })
        
        if did_no_screens:
            data.append({
                'type': 'habit',
                'date': current_date.isoformat(),
                'habit_id': habits['no_screens'],
                'habit_name': 'No screens last hour',
                'value': True,
            })
        
        if did_consistent_bedtime:
            data.append({
                'type': 'habit',
                'date': current_date.isoformat(),
                'habit_id': habits['consistent_bedtime'],
                'habit_name': 'Bedtime between 22:30-23:30',
                'value': True,
            })
        
        current_date += timedelta(days=1)
    
    return data


def save_to_csv(data: List[Dict[str, Any]], filename: str):
    """Save data to CSV file."""
    
    if not data:
        print("No data to save")
        return
    
    # Separate sleep and habit entries
    sleep_entries = [d for d in data if d['type'] == 'sleep']
    habit_entries = [d for d in data if d['type'] == 'habit']
    
    # Write to CSV
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        
        # Header
        writer.writerow(['type', 'date', 'sleep_score', 'duration_minutes', 'bedtime', 'wake_time', 'habit_id', 'habit_name', 'value'])
        
        # Write sleep entries
        for entry in sleep_entries:
            writer.writerow([
                'sleep',
                entry['date'],
                entry['sleep_score'],
                entry['duration_minutes'],
                entry['bedtime'],
                entry['wake_time'],
                '',  # no habit_id
                '',  # no habit_name
                '',  # no value
            ])
        
        # Write habit entries
        for entry in habit_entries:
            writer.writerow([
                'habit',
                entry['date'],
                '',  # no sleep_score
                '',  # no duration_minutes
                '',  # no bedtime
                '',  # no wake_time
                entry['habit_id'],
                entry['habit_name'],
                entry['value'],
            ])
    
    print(f"✅ Saved {len(sleep_entries)} sleep entries and {len(habit_entries)} habit checkins to {filename}")


if __name__ == '__main__':
    # Generate data from July 7 to Oct 7, 2025 (3 months)
    start = date(2025, 7, 7)
    end = date(2025, 10, 7)
    
    print(f"Generating synthetic sleep and habit data from {start} to {end}...")
    
    data = generate_realistic_sleep_data(start, end)
    
    save_to_csv(data, 'sleep_habits_export.csv')
    
    # Print some statistics
    sleep_count = sum(1 for d in data if d['type'] == 'sleep')
    habit_count = sum(1 for d in data if d['type'] == 'habit')
    avg_score = sum(d['sleep_score'] for d in data if d['type'] == 'sleep') / sleep_count
    
    print(f"\n📊 Statistics:")
    print(f"   Sleep sessions: {sleep_count}")
    print(f"   Habit checkins: {habit_count}")
    print(f"   Average sleep score: {avg_score:.1f}")
    print(f"\n💡 Next step: Upload 'sleep_habits_export.csv' in the app!")
