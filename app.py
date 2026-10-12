"""Student Management System - Flask application.

One small app used for the whole DevOps pipeline:
Git -> GitHub Actions -> Docker -> Kubernetes -> Prometheus -> Grafana.
"""
import os
import re
import sqlite3
import time

from flask import (
    Flask,
    Response,
    g,
    jsonify,
    redirect,
    render_template,
    request,
    url_for,
)
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)

BRANCHES = [
    "Information Technology",
    "Computer Engineering",
    "Computer Science",
    "Electronics and Telecommunication",
    "Mechanical",
    "Civil",
]
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

# ---------------------------------------------------------------------------
# Prometheus metrics (module level: one set of metrics per process)
# Labels are deliberately low-cardinality: method, route pattern, status code.
# ---------------------------------------------------------------------------
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests handled by the application",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
)
STUDENT_COUNT = Gauge("students_total", "Number of students stored in the database")
STUDENTS_ADDED = Counter("students_added_total", "Students successfully added")
VALIDATION_ERRORS = Counter(
    "student_validation_errors_total", "Rejected student submissions (validation or duplicate)"
)

UNINSTRUMENTED_PATHS = {"/metrics", "/health"}  # avoid counting scrapes and probes


def validate_student(data):
    """Return (clean_data, errors). `errors` maps field name -> message."""
    errors = {}
    name = str(data.get("name", "") or "").strip()
    email = str(data.get("email", "") or "").strip().lower()
    branch = str(data.get("branch", "") or "").strip()
    year_raw = data.get("year", "")

    if not 2 <= len(name) <= 100:
        errors["name"] = "Name must be 2 to 100 characters."
    if len(email) > 120 or not EMAIL_RE.match(email):
        errors["email"] = "Enter a valid email address."
    if branch not in BRANCHES:
        errors["branch"] = "Select a branch from the list."
    try:
        year = int(str(year_raw).strip())
        if not 1 <= year <= 4:
            raise ValueError
    except ValueError:
        year = None
        errors["year"] = "Year of study must be a number from 1 to 4."

    return {"name": name, "email": email, "branch": branch, "year": year}, errors


def create_app(test_config=None):
    app = Flask(__name__)
    app.config["DATABASE"] = os.environ.get("DATABASE_PATH", "students.db")
    if test_config:
        app.config.update(test_config)

    # ---------------- database helpers ----------------
    def get_db():
        if "db" not in g:
            g.db = sqlite3.connect(app.config["DATABASE"])
            g.db.row_factory = sqlite3.Row
        return g.db

    @app.teardown_appcontext
    def close_db(_exc):
        db = g.pop("db", None)
        if db is not None:
            db.close()

    def init_db():
        path = app.config["DATABASE"]
        folder = os.path.dirname(os.path.abspath(path))
        os.makedirs(folder, exist_ok=True)
        with sqlite3.connect(path) as conn:
            conn.execute(
                """CREATE TABLE IF NOT EXISTS students (
                       id INTEGER PRIMARY KEY AUTOINCREMENT,
                       name TEXT NOT NULL,
                       email TEXT NOT NULL UNIQUE,
                       branch TEXT NOT NULL,
                       year INTEGER NOT NULL
                   )"""
            )

    init_db()

    def list_students():
        rows = get_db().execute("SELECT * FROM students ORDER BY id").fetchall()
        return [dict(r) for r in rows]

    def insert_student(clean):
        """Insert a student. Returns (id, error_message_or_None)."""
        try:
            db = get_db()
            cur = db.execute(
                "INSERT INTO students (name, email, branch, year) VALUES (?, ?, ?, ?)",
                (clean["name"], clean["email"], clean["branch"], clean["year"]),
            )
            db.commit()
            STUDENTS_ADDED.inc()
            return cur.lastrowid, None
        except sqlite3.IntegrityError:
            return None, "A student with this email already exists."

    # ---------------- metrics hooks ----------------
    @app.before_request
    def start_timer():
        g.start_time = time.perf_counter()

    @app.after_request
    def record_metrics(response):
        if request.path not in UNINSTRUMENTED_PATHS and hasattr(g, "start_time"):
            # url_rule is the route *pattern*, so /api/students/7 and /api/students/8
            # share one label value. Unknown URLs become "unmatched" (bounded cardinality).
            endpoint = request.url_rule.rule if request.url_rule else "unmatched"
            REQUEST_COUNT.labels(request.method, endpoint, str(response.status_code)).inc()
            REQUEST_LATENCY.labels(request.method, endpoint).observe(
                time.perf_counter() - g.start_time
            )
        return response

    # ---------------- web pages ----------------
    @app.get("/")
    def index():
        return render_template(
            "index.html",
            students=list_students(),
            branches=BRANCHES,
            form={},
            errors={},
            added=request.args.get("added") == "1",
        )

    @app.post("/students")
    def add_student_form():
        clean, errors = validate_student(request.form)
        if not errors:
            _id, err = insert_student(clean)
            if err:
                errors["email"] = err
        if errors:
            VALIDATION_ERRORS.inc()
            return (
                render_template(
                    "index.html",
                    students=list_students(),
                    branches=BRANCHES,
                    form=request.form,
                    errors=errors,
                    added=False,
                ),
                400,
            )
        return redirect(url_for("index", added=1))

    # ---------------- JSON API ----------------
    @app.get("/api/students")
    def api_list():
        return jsonify(list_students())

    @app.post("/api/students")
    def api_create():
        data = request.get_json(silent=True)
        if not isinstance(data, dict):
            return jsonify({"error": "Request body must be a JSON object."}), 400
        clean, errors = validate_student(data)
        if errors:
            VALIDATION_ERRORS.inc()
            return jsonify({"error": "Validation failed.", "fields": errors}), 400
        new_id, err = insert_student(clean)
        if err:
            VALIDATION_ERRORS.inc()
            return jsonify({"error": err, "fields": {"email": err}}), 409
        clean["id"] = new_id
        return jsonify(clean), 201

    @app.get("/api/students/<int:student_id>")
    def api_get(student_id):
        row = get_db().execute("SELECT * FROM students WHERE id = ?", (student_id,)).fetchone()
        if row is None:
            return jsonify({"error": "Student not found."}), 404
        return jsonify(dict(row))

    # ---------------- operations endpoints ----------------
    @app.get("/health")
    def health():
        try:
            get_db().execute("SELECT 1").fetchone()
        except sqlite3.Error:
            return jsonify({"status": "unhealthy", "database": "unreachable"}), 503
        return jsonify({"status": "ok", "database": "reachable"})

    @app.get("/metrics")
    def metrics():
        count = get_db().execute("SELECT COUNT(*) FROM students").fetchone()[0]
        STUDENT_COUNT.set(count)
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

    # ---------------- error handling ----------------
    @app.errorhandler(404)
    def not_found(_e):
        return jsonify({"error": "Not found."}), 404

    @app.errorhandler(405)
    def method_not_allowed(_e):
        return jsonify({"error": "Method not allowed."}), 405

    @app.errorhandler(500)
    def server_error(_e):
        return jsonify({"error": "Internal server error."}), 500

    return app


if __name__ == "__main__":
    # Local development only. In Docker/Kubernetes, gunicorn runs "app:create_app()".
    create_app().run(
        host=os.environ.get("HOST", "127.0.0.1"),
        port=int(os.environ.get("PORT", "5000")),
        debug=os.environ.get("FLASK_DEBUG") == "1",
    )
