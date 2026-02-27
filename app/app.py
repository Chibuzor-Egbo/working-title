import os
from datetime import datetime, timezone
import time
from sqlalchemy import text

from dotenv import load_dotenv
from flask import Flask, jsonify, render_template, request
from flask_sqlalchemy import SQLAlchemy
from prometheus_client import (
    Counter,
    Histogram,
    Gauge,
    generate_latest,
    CONTENT_TYPE_LATEST,
)

load_dotenv()

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", "change-me")
app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get(
    "DATABASE_URL", "sqlite:///:memory:"
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

# ---------------------------------------------------------------------------
# Prometheus Metrics
# ---------------------------------------------------------------------------

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "http_status"]
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "endpoint"]
)

DB_CONNECTIONS = Gauge(
    "db_active_connections",
    "Active database connections"
)


# ---------------------------------------------------------------------------
# Model – maps to the existing "todos" table
# ---------------------------------------------------------------------------
class Todo(db.Model):
    __tablename__ = "todos"

    id = db.Column(db.Integer, primary_key=True)
    content = db.Column(db.Text, nullable=False)
    is_completed = db.Column(db.Boolean, nullable=False, default=False)
    is_deleted = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(
        db.DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    completed_at = db.Column(db.DateTime(timezone=True), nullable=True)

    def to_dict(self):
        return {
            "id": self.id,
            "content": self.content,
            "is_completed": self.is_completed,
            "is_deleted": self.is_deleted,
            "created_at": self.created_at.isoformat(),
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
        }

def update_db_connection_gauge():
    try:
        result = db.session.execute(
            text("SELECT count(*) FROM pg_stat_activity;")
        )
        count = result.scalar()
        DB_CONNECTIONS.set(count)
    except Exception:
        pass

# ---------------------------------------------------------------------------
# Flask hooks for tracking HTTP requests  and latency automatically
# ---------------------------------------------------------------------------  
@app.before_request
def start_timer():
    request.start_time = time.time()


@app.after_request
def record_metrics(response):
    resp_time = time.time() - request.start_time

    endpoint = request.path
    method = request.method
    status = response.status_code

    REQUEST_COUNT.labels(method=method, endpoint=endpoint, http_status=status).inc()
    REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(resp_time)

    update_db_connection_gauge()

    return response


# ---------------------------------------------------------------------------
# Pages
# ---------------------------------------------------------------------------
@app.route("/")
def index():
    return render_template("index.html")


# ---------------------------------------------------------------------------
# API endpoints
# ---------------------------------------------------------------------------
@app.route("/todos", methods=["GET"])
def list_todos():
    """Return all non-deleted todos, completed ones last."""
    todos = (
        Todo.query
        .filter_by(is_deleted=False)
        .order_by(Todo.is_completed.asc(), Todo.created_at.desc())
        .all()
    )
    return jsonify([t.to_dict() for t in todos])


@app.route("/todos", methods=["POST"])
def create_todo():
    data = request.get_json(silent=True) or {}
    content = (data.get("content") or "").strip()
    if not content:
        return jsonify({"error": "content is required"}), 400

    todo = Todo(content=content)
    db.session.add(todo)
    db.session.commit()
    return jsonify(todo.to_dict()), 201


@app.route("/todos/<int:todo_id>", methods=["PUT"])
def update_todo(todo_id):
    todo = db.get_or_404(Todo, todo_id)
    data = request.get_json(silent=True) or {}

    if "content" in data:
        new_content = (data["content"] or "").strip()
        if not new_content:
            return jsonify({"error": "content cannot be empty"}), 400
        todo.content = new_content

    if "is_completed" in data:
        was_completed = todo.is_completed
        todo.is_completed = bool(data["is_completed"])
        if todo.is_completed and not was_completed:
            todo.completed_at = datetime.now(timezone.utc)
        elif not todo.is_completed:
            todo.completed_at = None

    db.session.commit()
    return jsonify(todo.to_dict())


@app.route("/todos/<int:todo_id>", methods=["DELETE"])
def delete_todo(todo_id):
    todo = db.get_or_404(Todo, todo_id)
    todo.is_deleted = True
    db.session.commit()
    return "", 204


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({"status": "healthy"})

@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}

# Temporarily skip DB
try:
    with app.app_context():
    	db.create_all()
except Exception as e:
    print("Skipping DB setup:", e)

if __name__ == "__main__":
    app.run(debug=True)
