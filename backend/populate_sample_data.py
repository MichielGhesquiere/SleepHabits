"""
Populate sample sleep and habit data for July-September 2025
Run this script to add historical data for testing analytics
"""
import random
from datetime import date, timedelta
from app.services.storage import store, User, SleepSession, HabitCheckin

# Create or get demo user
demo_user = store.get_user_by_email("demo@sleephabits.app")
if not demo_user:
    demo_user = User(id="demo-user-001", email="demo@sleephabits.app")
    store.upsert_user(demo_user)

print(f"Populating data for user: {demo_user.email}")

# Define habits (these should match the defaults from HabitService)
HEALTHY_HABITS = [
    ("habit-read", "Read ≥15min"),
    ("habit-meditate", "Meditate ≥10min"),
    ("habit-no-screens", "No screens 1h before bed"),
]

UNHEALTHY_HABITS = [
    ("habit-alcohol", "Alcohol (any)"),
    ("habit-caffeine", "Caffeine after 14:00"),
    ("habit-screens", "Screens in last hour"),
]

# Generate data from July 7 to Oct 6, 2025 (3 months)
start_date = date(2025, 7, 7)
end_date = date(2025, 10, 6)

current_date = start_date
sleep_sessions = []
habit_checkins = []

print(f"Generating data from {start_date} to {end_date}")

while current_date <= end_date:
    # Generate sleep score with some patterns
    # Base score varies by day of week
    day_of_week = current_date.weekday()
    
    # Weekend scores tend to be slightly better
    base_score = 75 if day_of_week < 5 else 80
    
    # Add some randomness
    sleep_score = max(40, min(100, base_score + random.randint(-15, 15)))
    
    # Duration correlates loosely with score
    duration_minutes = int(360 + (sleep_score - 70) * 2 + random.randint(-30, 30))
    duration_minutes = max(300, min(540, duration_minutes))  # 5-9 hours
    
    # Bedtime varies
    bedtime_hour = 22 + random.randint(-1, 2)
    bedtime_min = random.choice([0, 15, 30, 45])
    bedtime = f"{bedtime_hour:02d}:{bedtime_min:02d}"
    
    # Wake time based on duration
    wake_minutes = (bedtime_hour * 60 + bedtime_min + duration_minutes) % (24 * 60)
    wake_hour = wake_minutes // 60
    wake_min = wake_minutes % 60
    wake_time = f"{wake_hour:02d}:{wake_min:02d}"
    
    # Create sleep session
    session = SleepSession(
        user_id=demo_user.id,
        date=current_date,
        duration_minutes=duration_minutes,
        bedtime=bedtime,
        wake_time=wake_time,
        sleep_score=sleep_score,
        stage_minutes={},
    )
    sleep_sessions.append(session)
    
    # Generate habit checkins with patterns that affect sleep
    # Reading improves sleep slightly
    read = random.random() < 0.6  # 60% of days
    if read:
        checkin = HabitCheckin(
            user_id=demo_user.id,
            habit_id="habit-read",
            local_date=current_date,
            value=True,
        )
        habit_checkins.append(checkin)
    
    # Meditation improves sleep
    meditate = random.random() < 0.4  # 40% of days
    if meditate:
        checkin = HabitCheckin(
            user_id=demo_user.id,
            habit_id="habit-meditate",
            local_date=current_date,
            value=True,
        )
        habit_checkins.append(checkin)
    
    # No screens before bed improves sleep
    no_screens = random.random() < 0.5  # 50% of days
    if no_screens:
        checkin = HabitCheckin(
            user_id=demo_user.id,
            habit_id="habit-no-screens",
            local_date=current_date,
            value=True,
        )
        habit_checkins.append(checkin)
    
    # Alcohol worsens sleep
    alcohol = random.random() < 0.25  # 25% of days
    if alcohol:
        checkin = HabitCheckin(
            user_id=demo_user.id,
            habit_id="habit-alcohol",
            local_date=current_date,
            value=True,
        )
        habit_checkins.append(checkin)
    
    # Caffeine late worsens sleep
    caffeine = random.random() < 0.30  # 30% of days
    if caffeine:
        checkin = HabitCheckin(
            user_id=demo_user.id,
            habit_id="habit-caffeine",
            local_date=current_date,
            value=True,
        )
        habit_checkins.append(checkin)
    
    # Screens before bed worsens sleep
    screens = random.random() < 0.35  # 35% of days
    if screens:
        checkin = HabitCheckin(
            user_id=demo_user.id,
            habit_id="habit-screens",
            local_date=current_date,
            value=True,
        )
        habit_checkins.append(checkin)
    
    current_date += timedelta(days=1)

# Store all data
print(f"Storing {len(sleep_sessions)} sleep sessions...")
store.overwrite_sleep_sessions(demo_user.id, sleep_sessions)

print(f"Storing {len(habit_checkins)} habit checkins...")
for checkin in habit_checkins:
    store.record_checkin(checkin)

print("✅ Sample data populated successfully!")
print(f"   Sleep sessions: {len(sleep_sessions)}")
print(f"   Habit checkins: {len(habit_checkins)}")
print(f"   Date range: {start_date} to {end_date}")
