(() => {
  const STORAGE_KEY = 'todos:v1';
  let todos = [];

  const els = {
    form: document.getElementById('todo-form'),
    input: document.getElementById('todo-input'),
    list: document.getElementById('todo-list'),
    empty: document.getElementById('empty-state'),
    count: document.getElementById('count'),
    clearCompleted: document.getElementById('clear-completed'),
  };

  function load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      todos = raw ? JSON.parse(raw) : [];
    } catch {
      todos = [];
    }
  }

  function save() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(todos));
  }

  function nextId() {
    return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  }

  function addTodo(text) {
    const t = text.trim();
    if (!t) return;
    todos.unshift({ id: nextId(), text: t, completed: false, createdAt: Date.now() });
    save();
    render();
  }

  function toggleTodo(id, completed) {
    const t = todos.find(x => x.id === id);
    if (t) {
      t.completed = completed;
      save();
      render();
    }
  }

  function deleteTodo(id) {
    todos = todos.filter(x => x.id !== id);
    save();
    render();
  }

  function clearCompleted() {
    const before = todos.length;
    todos = todos.filter(x => !x.completed);
    if (todos.length !== before) {
      save();
      render();
    }
  }

  function renderCounts() {
    const active = todos.filter(t => !t.completed).length;
    els.count.textContent = `${active} ${active === 1 ? 'item' : 'items'}`;
  }

  function render() {
    els.list.innerHTML = '';
    if (todos.length === 0) {
      els.empty.style.display = 'block';
    } else {
      els.empty.style.display = 'none';
    }

    todos.forEach(t => {
      const li = document.createElement('li');
      li.className = 'todo-item' + (t.completed ? ' completed' : '');
      li.dataset.id = t.id;

      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.checked = t.completed;
      checkbox.setAttribute('aria-label', 'Mark todo complete');
      checkbox.addEventListener('change', () => toggleTodo(t.id, checkbox.checked));

      const text = document.createElement('span');
      text.className = 'todo-text';
      text.textContent = t.text;

      const del = document.createElement('button');
      del.className = 'delete-btn';
      del.setAttribute('aria-label', 'Delete todo');
      del.innerHTML = `
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
             stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <polyline points="3 6 5 6 21 6"></polyline>
          <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"></path>
          <path d="M10 11v6M14 11v6"></path>
          <path d="M9 6V4a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"></path>
        </svg>
      `;
      del.addEventListener('click', () => deleteTodo(t.id));

      li.appendChild(checkbox);
      li.appendChild(text);
      li.appendChild(del);

      els.list.appendChild(li);
    });

    renderCounts();
  }

  function onSubmit(e) {
    e.preventDefault();
    addTodo(els.input.value);
    els.input.value = '';
    els.input.focus();
  }

  function init() {
    load();
    render();

    els.form.addEventListener('submit', onSubmit);
    els.clearCompleted.addEventListener('click', clearCompleted);
  }

  document.addEventListener('DOMContentLoaded', init);
})();
