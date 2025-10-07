from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def authenticate(email: str = "codex@example.com") -> str:
    response = client.post("/auth/login", json={"email": email})
    assert response.status_code == 200, response.text
    payload = response.json()
    return payload["access_token"]


def test_login_and_summary_flow() -> None:
    token = authenticate()

    summary = client.get("/me/summary", headers={"Authorization": f"Bearer {token}"})
    assert summary.status_code == 200
    data = summary.json()
    assert data["user"]["email"] == "codex@example.com"
    assert data["last_night"] is None

    connect = client.post(
        "/me/garmin/connect",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert connect.status_code == 200
    connect_payload = connect.json()
    assert connect_payload["connected"] is True
    assert connect_payload["summary"]["last_night"] is not None

    habits = client.get(
        "/me/habits",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert habits.status_code == 200
    habit_items = habits.json()
    assert any(h["type"] == "healthy" for h in habit_items)

    checkin = client.post(
        "/me/habits/checkin",
        json={"habit_id": habit_items[0]["id"], "value": True},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert checkin.status_code == 200
    checkin_payload = checkin.json()
    assert checkin_payload["value"] is True

    refreshed = client.get(
        "/me/summary",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert refreshed.status_code == 200
    refreshed_data = refreshed.json()
    assert refreshed_data["last_night"] is not None
