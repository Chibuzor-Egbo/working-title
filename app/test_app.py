import os
import pytest
from datetime import datetime, timezone
from app import app as flask_app, db, Todo


@pytest.fixture
def app():
    """Create and configure a test app instance."""
    flask_app.config.update({
        "TESTING": True,
        "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",
        "SQLALCHEMY_TRACK_MODIFICATIONS": False,
    })
    
    with flask_app.app_context():
        db.create_all()
        yield flask_app
        db.session.remove()
        db.drop_all()


@pytest.fixture
def client(app):
    """A test client for the app."""
    return app.test_client()


@pytest.fixture
def runner(app):
    """A test CLI runner for the app."""
    return app.test_cli_runner()


# ---------------------------------------------------------------------------
# Health endpoint tests
# ---------------------------------------------------------------------------
def test_health_endpoint(client):
    """Test the health endpoint returns the correct shape."""
    response = client.get("/health")
    assert response.status_code == 200
    
    data = response.get_json()
    assert "status" in data
    assert data["status"] == "healthy"


# ---------------------------------------------------------------------------
# Create todo tests
# ---------------------------------------------------------------------------
def test_create_todo_success(client):
    """Test creating a todo with valid content."""
    response = client.post("/todos", json={"content": "Test todo item"})
    assert response.status_code == 201
    
    data = response.get_json()
    assert data["content"] == "Test todo item"
    assert data["is_completed"] is False
    assert data["is_deleted"] is False
    assert data["id"] is not None
    assert data["created_at"] is not None
    assert data["completed_at"] is None


def test_create_todo_empty_content(client):
    """Test creating a todo with empty content returns error."""
    response = client.post("/todos", json={"content": ""})
    assert response.status_code == 400
    
    data = response.get_json()
    assert "error" in data
    assert data["error"] == "content is required"


def test_create_todo_whitespace_content(client):
    """Test creating a todo with only whitespace returns error."""
    response = client.post("/todos", json={"content": "   "})
    assert response.status_code == 400
    
    data = response.get_json()
    assert "error" in data


def test_create_todo_missing_content(client):
    """Test creating a todo without content field returns error."""
    response = client.post("/todos", json={})
    assert response.status_code == 400
    
    data = response.get_json()
    assert "error" in data


def test_create_todo_no_json(client):
    """Test creating a todo without JSON body returns error."""
    response = client.post("/todos")
    assert response.status_code == 400


# ---------------------------------------------------------------------------
# List todos tests
# ---------------------------------------------------------------------------
def test_list_todos_empty(client):
    """Test listing todos when database is empty."""
    response = client.get("/todos")
    assert response.status_code == 200
    
    data = response.get_json()
    assert isinstance(data, list)
    assert len(data) == 0


def test_list_todos_multiple(client):
    """Test listing multiple todos."""
    # Create some todos
    client.post("/todos", json={"content": "First todo"})
    client.post("/todos", json={"content": "Second todo"})
    client.post("/todos", json={"content": "Third todo"})
    
    response = client.get("/todos")
    assert response.status_code == 200
    
    data = response.get_json()
    assert len(data) == 3
    # Most recent should be first (for non-completed todos)
    assert data[0]["content"] == "Third todo"


def test_list_todos_excludes_deleted(client):
    """Test that listing todos excludes deleted ones."""
    # Create and delete a todo
    response = client.post("/todos", json={"content": "To be deleted"})
    todo_id = response.get_json()["id"]
    client.delete(f"/todos/{todo_id}")
    
    # Create another todo
    client.post("/todos", json={"content": "Active todo"})
    
    response = client.get("/todos")
    data = response.get_json()
    
    assert len(data) == 1
    assert data[0]["content"] == "Active todo"


def test_list_todos_completed_last(client):
    """Test that completed todos appear after non-completed ones."""
    # Create todos
    response1 = client.post("/todos", json={"content": "First todo"})
    todo1_id = response1.get_json()["id"]
    
    client.post("/todos", json={"content": "Second todo"})
    
    response3 = client.post("/todos", json={"content": "Third todo"})
    todo3_id = response3.get_json()["id"]
    
    # Mark first and third as completed
    client.put(f"/todos/{todo1_id}", json={"is_completed": True})
    client.put(f"/todos/{todo3_id}", json={"is_completed": True})
    
    response = client.get("/todos")
    data = response.get_json()
    
    assert len(data) == 3
    # Non-completed should come first
    assert data[0]["is_completed"] is False
    assert data[0]["content"] == "Second todo"
    # Completed should come after
    assert data[1]["is_completed"] is True
    assert data[2]["is_completed"] is True


# ---------------------------------------------------------------------------
# Update todo tests (focusing on is_completed)
# ---------------------------------------------------------------------------
def test_update_todo_mark_completed(client):
    """Test updating a todo to mark it as completed."""
    # Create a todo
    response = client.post("/todos", json={"content": "Test todo"})
    todo_id = response.get_json()["id"]
    
    # Mark as completed
    response = client.put(f"/todos/{todo_id}", json={"is_completed": True})
    assert response.status_code == 200
    
    data = response.get_json()
    assert data["is_completed"] is True
    assert data["completed_at"] is not None


def test_update_todo_mark_uncompleted(client):
    """Test updating a todo to mark it as not completed."""
    # Create and complete a todo
    response = client.post("/todos", json={"content": "Test todo"})
    todo_id = response.get_json()["id"]
    client.put(f"/todos/{todo_id}", json={"is_completed": True})
    
    # Mark as not completed
    response = client.put(f"/todos/{todo_id}", json={"is_completed": False})
    assert response.status_code == 200
    
    data = response.get_json()
    assert data["is_completed"] is False
    assert data["completed_at"] is None


def test_update_todo_content(client):
    """Test updating a todo's content."""
    # Create a todo
    response = client.post("/todos", json={"content": "Original content"})
    todo_id = response.get_json()["id"]
    
    # Update content
    response = client.put(f"/todos/{todo_id}", json={"content": "Updated content"})
    assert response.status_code == 200
    
    data = response.get_json()
    assert data["content"] == "Updated content"


def test_update_todo_empty_content(client):
    """Test updating a todo with empty content returns error."""
    # Create a todo
    response = client.post("/todos", json={"content": "Original content"})
    todo_id = response.get_json()["id"]
    
    # Try to update with empty content
    response = client.put(f"/todos/{todo_id}", json={"content": ""})
    assert response.status_code == 400
    
    data = response.get_json()
    assert "error" in data


def test_update_todo_both_fields(client):
    """Test updating both content and is_completed."""
    # Create a todo
    response = client.post("/todos", json={"content": "Original content"})
    todo_id = response.get_json()["id"]
    
    # Update both fields
    response = client.put(f"/todos/{todo_id}", json={
        "content": "New content",
        "is_completed": True
    })
    assert response.status_code == 200
    
    data = response.get_json()
    assert data["content"] == "New content"
    assert data["is_completed"] is True
    assert data["completed_at"] is not None


def test_update_todo_not_found(client):
    """Test updating a non-existent todo returns 404."""
    response = client.put("/todos/99999", json={"is_completed": True})
    assert response.status_code == 404


# ---------------------------------------------------------------------------
# Delete todo tests
# ---------------------------------------------------------------------------
def test_delete_todo_success(client):
    """Test deleting a todo."""
    # Create a todo
    response = client.post("/todos", json={"content": "To be deleted"})
    todo_id = response.get_json()["id"]
    
    # Delete it
    response = client.delete(f"/todos/{todo_id}")
    assert response.status_code == 204
    assert response.data == b""
    
    # Verify it's not in the list
    response = client.get("/todos")
    data = response.get_json()
    assert len(data) == 0


def test_delete_todo_soft_delete(client, app):
    """Test that delete is a soft delete (is_deleted flag)."""
    # Create a todo
    response = client.post("/todos", json={"content": "To be deleted"})
    todo_id = response.get_json()["id"]
    
    # Delete it
    client.delete(f"/todos/{todo_id}")
    
    # Verify it still exists in database with is_deleted=True
    with app.app_context():
        todo = db.session.get(Todo, todo_id)
        assert todo is not None
        assert todo.is_deleted is True


def test_delete_todo_not_found(client):
    """Test deleting a non-existent todo returns 404."""
    response = client.delete("/todos/99999")
    assert response.status_code == 404


def test_delete_completed_todo(client):
    """Test deleting a completed todo."""
    # Create and complete a todo
    response = client.post("/todos", json={"content": "Completed todo"})
    todo_id = response.get_json()["id"]
    client.put(f"/todos/{todo_id}", json={"is_completed": True})
    
    # Delete it
    response = client.delete(f"/todos/{todo_id}")
    assert response.status_code == 204
    
    # Verify it's not in the list
    response = client.get("/todos")
    data = response.get_json()
    assert len(data) == 0
