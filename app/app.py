import os
from datetime import datetime, timezone

from dotenv import load_dotenv
from flask import Flask, jsonify, render_template, request
from flask_sqlalchemy import SQLAlchemy

load_dotenv()

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", "change-me")
app.config["SQLALCHEMY_DATABASE_URI"] = os.environ["DATABASE_URL"]
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)


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


if __name__ == "__main__":
    app.run(debug=True)
