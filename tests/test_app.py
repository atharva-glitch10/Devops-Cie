import pytest

from app import REQUEST_COUNT, create_app

VALID = {
    "name": "Asha Patil",
    "email": "asha@example.com",
    "branch": "Information Technology",
    "year": 3,
}


@pytest.fixture()
def client(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "test.db")})
    return app.test_client()


def test_home_page_loads_empty(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert b"Student Management System" in resp.data
    assert b"No students yet" in resp.data


def test_health_endpoint(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_add_student_via_api_and_list(client):
    resp = client.post("/api/students", json=VALID)
    assert resp.status_code == 201
    body = resp.get_json()
    assert body["id"] == 1
    assert body["email"] == "asha@example.com"

    listing = client.get("/api/students").get_json()
    assert len(listing) == 1
    assert listing[0]["name"] == "Asha Patil"

    assert client.get("/api/students/1").status_code == 200
    assert client.get("/api/students/999").status_code == 404


def test_add_student_via_form_shows_on_home_page(client):
    resp = client.post("/students", data=VALID, follow_redirects=True)
    assert resp.status_code == 200
    assert b"Student added successfully" in resp.data
    assert b"asha@example.com" in resp.data


@pytest.mark.parametrize(
    "field,value",
    [
        ("name", "A"),
        ("email", "not-an-email"),
        ("branch", "Underwater Basket Weaving"),
        ("year", 9),
        ("year", "abc"),
    ],
)
def test_validation_rejects_bad_input(client, field, value):
    payload = {**VALID, field: value}
    resp = client.post("/api/students", json=payload)
    assert resp.status_code == 400
    assert field in resp.get_json()["fields"]
    assert client.get("/api/students").get_json() == []


def test_form_validation_shows_errors(client):
    resp = client.post("/students", data={**VALID, "email": "bad"})
    assert resp.status_code == 400
    assert b"Enter a valid email address" in resp.data


def test_duplicate_email_is_rejected(client):
    assert client.post("/api/students", json=VALID).status_code == 201
    resp = client.post("/api/students", json=VALID)
    assert resp.status_code == 409
    assert "already exists" in resp.get_json()["error"]


def test_non_json_body_is_rejected(client):
    resp = client.post("/api/students", data="plain text", content_type="text/plain")
    assert resp.status_code == 400


def test_unknown_route_returns_json_404(client):
    resp = client.get("/does-not-exist")
    assert resp.status_code == 404
    assert resp.get_json()["error"] == "Not found."


def test_metrics_endpoint_exposes_expected_metrics(client):
    client.get("/")
    client.post("/api/students", json=VALID)
    resp = client.get("/metrics")
    assert resp.status_code == 200
    text = resp.get_data(as_text=True)
    assert "http_requests_total" in text
    assert "http_request_duration_seconds_bucket" in text
    assert "students_total 1.0" in text


def test_request_counter_increases(client):
    counter = REQUEST_COUNT.labels("GET", "/api/students", "200")
    before = counter._value.get()
    client.get("/api/students")
    client.get("/api/students")
    assert counter._value.get() == before + 2


def test_metric_labels_use_route_pattern_not_raw_url(client):
    client.get("/api/students/12345")
    text = client.get("/metrics").get_data(as_text=True)
    assert 'endpoint="/api/students/<int:student_id>"' in text
    assert "12345" not in text
