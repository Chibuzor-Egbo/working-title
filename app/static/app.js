(() => {
  let todos = [];

  const els = {
    form: document.getElementById('todo-form'),
    input: document.getElementById('todo-input'),
    list: document.getElementById('todo-list'),
    empty: document.getElementById('empty-state'),
    count: document.getElementById('count'),
    clearCompleted: document.getElementById('clear-completed'),
  };

  // ---------- API helpers ----------
  async function api(url, opts = {}) {
    const res = await fetch(url, {
      headers: { 'Content-Type': 'application/json' },
      ...opts,
    });
    if (res.status === 204) return null;
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || res.statusText);
    }
    return res.json();
  }

  async function fetchTodos() {
    todos = await api('/todos');
    render();
  }

  async function addTodo(text) {
    const content = text.trim();
    if (!content) return;
    await api('/todos', {
      method: 'POST',
      body: JSON.stringify({ content }),
    });
    await fetchTodos();
  }

  async function toggleTodo(id, completed) {
    await api(`/todos/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ is_completed: completed }),
    });
    await fetchTodos();
  }

  async function deleteTodo(id) {
    await api(`/todos/${id}`, { method: 'DELETE' });
    await fetchTodos();
  }

  async function clearCompleted() {
    const completed = todos.filter(t => t.is_completed);
    await Promise.all(completed.map(t => api(`/todos/${t.id}`, { method: 'DELETE' })));
    await fetchTodos();
  }

  // ---------- Rendering ----------
  function renderCounts() {
    const active = todos.filter(t => !t.is_completed).length;
    els.count.textContent = `${active} ${active === 1 ? 'item' : 'items'}`;
  }

  function render() {
    els.list.innerHTML = '';
    els.empty.style.display = todos.length === 0 ? 'block' : 'none';

    todos.forEach(t => {
      const li = document.createElement('li');
      li.className = 'todo-item' + (t.is_completed ? ' completed' : '');
      li.dataset.id = t.id;

      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.checked = t.is_completed;
      checkbox.setAttribute('aria-label', 'Mark todo complete');
      checkbox.addEventListener('change', () => toggleTodo(t.id, checkbox.checked));

      const text = document.createElement('span');
      text.className = 'todo-text';
      text.textContent = t.content;

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

  // ---------- Init ----------
  async function onSubmit(e) {
    e.preventDefault();
    await addTodo(els.input.value);
    els.input.value = '';
    els.input.focus();
  }

  function init() {
    fetchTodos();
    els.form.addEventListener('submit', onSubmit);
    els.clearCompleted.addEventListener('click', clearCompleted);
  }

  document.addEventListener('DOMContentLoaded', init);
})();
