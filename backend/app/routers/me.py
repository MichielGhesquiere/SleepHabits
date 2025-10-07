from __future__ import annotations

import csv
import io
from datetime import date
from typing import List, Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from app.schemas.habits import HabitCheckinRequest, HabitCheckinResponse, HabitResponse
from app.schemas.sleep import ManualSleepEntryRequest, SleepSummaryResponse
from app.services.habits import HabitService, get_habit_service
from app.services.sleep import SleepService, get_sleep_service
from app.services.storage import User
from app.services.users import get_current_user

router = APIRouter()


@router.get("/summary", response_model=SleepSummaryResponse)
async def get_summary(
    user: User = Depends(get_current_user),
    sleep_service: SleepService = Depends(get_sleep_service),
) -> SleepSummaryResponse:
    summary = sleep_service.get_summary(user)
    return SleepSummaryResponse(**summary)


@router.get("/habits", response_model=List[HabitResponse])
async def list_habits(
    target_date: Optional[date] = None,
    user: User = Depends(get_current_user),
    habit_service: HabitService = Depends(get_habit_service),
) -> List[HabitResponse]:
    habits = habit_service.get_habits(user, target_date)
    return [HabitResponse(**habit) for habit in habits]


@router.post("/habits/checkin", response_model=HabitCheckinResponse)
async def checkin_habit(
    payload: HabitCheckinRequest,
    user: User = Depends(get_current_user),
    habit_service: HabitService = Depends(get_habit_service),
) -> HabitCheckinResponse:
    habit = habit_service.check_in(
        user=user,
        habit_id=payload.habit_id,
        value=payload.value,
        target_date=payload.local_date,
    )
    return HabitCheckinResponse(**habit)


@router.get("/analytics")
async def get_analytics(
    user: User = Depends(get_current_user),
    sleep_service: SleepService = Depends(get_sleep_service),
) -> dict:
    """Get correlations between habits and sleep quality."""
    return sleep_service.get_analytics(user)


@router.get("/sleep/timeline")
async def get_sleep_timeline(
    range: str = "week",  # week, month, year
    user: User = Depends(get_current_user),
    sleep_service: SleepService = Depends(get_sleep_service),
) -> dict:
    """Get sleep timeline data for visualization."""
    return sleep_service.get_timeline(user, range)


@router.post("/sleep/manual", response_model=SleepSummaryResponse)
async def add_manual_sleep_entry(
    payload: ManualSleepEntryRequest,
    user: User = Depends(get_current_user),
    sleep_service: SleepService = Depends(get_sleep_service),
) -> SleepSummaryResponse:
    """Manually add a sleep entry for a specific date."""
    summary = sleep_service.add_manual_entry(
        user=user,
        local_date=payload.local_date,
        sleep_score=payload.sleep_score,
        bedtime=payload.bedtime,
        wake_time=payload.wake_time,
        duration_minutes=payload.duration_minutes,
    )
    return SleepSummaryResponse(**summary)


@router.post("/import/csv")
async def import_csv_data(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    sleep_service: SleepService = Depends(get_sleep_service),
    habit_service: HabitService = Depends(get_habit_service),
) -> dict:
    """Import sleep and habit data from CSV file."""
    
    # Read file content
    contents = await file.read()
    
    try:
        # Decode CSV
        csv_text = contents.decode('utf-8')
        csv_reader = csv.DictReader(io.StringIO(csv_text))
        
        sleep_count = 0
        habit_count = 0
        errors = []
        
        for row in csv_reader:
            try:
                row_type = row.get('type', '').strip()
                
                if row_type == 'sleep':
                    # Parse sleep entry
                    local_date = date.fromisoformat(row['date'])
                    sleep_score = int(row['sleep_score'])
                    duration_minutes = int(row['duration_minutes'])
                    bedtime = row['bedtime']
                    wake_time = row['wake_time']
                    
                    sleep_service.add_manual_entry(
                        user=user,
                        local_date=local_date,
                        sleep_score=sleep_score,
                        bedtime=bedtime,
                        wake_time=wake_time,
                        duration_minutes=duration_minutes,
                    )
                    sleep_count += 1
                
                elif row_type == 'habit':
                    # Parse habit checkin
                    local_date = date.fromisoformat(row['date'])
                    habit_id = row['habit_id']
                    value_str = row['value'].strip()
                    
                    # Try to parse as integer first, then as boolean
                    try:
                        value = int(value_str)
                    except ValueError:
                        value = value_str.lower() in ('true', '1', 'yes')
                    
                    habit_service.check_in(
                        user=user,
                        habit_id=habit_id,
                        value=value,
                        target_date=local_date,
                    )
                    habit_count += 1
            
            except Exception as e:
                errors.append(f"Row error: {str(e)}")
        
        return {
            'success': True,
            'sleep_imported': sleep_count,
            'habits_imported': habit_count,
            'errors': errors[:10],  # Limit error list
        }
    
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to parse CSV: {str(e)}")
