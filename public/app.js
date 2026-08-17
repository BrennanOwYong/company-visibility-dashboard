(() => {
  const list = document.querySelector('#navigation-list');
  const state = document.querySelector('#page-state');
  const sidebar = document.querySelector('.sidebar');
  const menuToggle = document.querySelector('.menu-toggle');
  let entries = [{ id:'connected-tools', kind:'fixed', title:'Connected Tools', icon_key:'plug', route:'/connected-tools' }, { id:'memory', kind:'fixed', title:'Memory', icon_key:'spark', route:'/memory' }, { id:'create-page', kind:'fixed', title:'Create page', icon_key:'plus', route:'/pages/new' }];
  let interactionId = '';
  const icons = { plug:'↔', spark:'✦', plus:'+', chart:'▥' };
  const emit = (name, fields = {}) => {
    const event = { name, interaction_id: interactionId || undefined, ...fields };
    navigator.sendBeacon('/api/v1/telemetry', new Blob([JSON.stringify(event)], { type:'application/json' }));
  };
  const render = (entry, view, extra = {}) => {
    document.title = `${entry.title} · Company dashboard`;
    state.innerHTML = `<section class="page-card" aria-labelledby="page-title"><p class="eyebrow">${view === 'empty' ? 'Welcome' : 'Workspace'}</p><h1 id="page-title">${entry.title}</h1><p>${extra.message || (entry.id === 'create-page' ? 'Describe the company page you want to create. We will help you shape it and save it here.' : entry.id === 'connected-tools' ? 'Connect the tools that contain the information your company needs.' : entry.id === 'memory' ? 'Review your organization Memory and its current summary.' : 'Your saved company page is ready to explore.')}</p>${view === 'empty' ? '<a class="empty-action" href="/pages/new" data-route="/pages/new">Create your first page</a>' : ''}${view === 'error' ? '<button class="retry" type="button" data-retry="">Retry</button>' : ''}</section>`;
    emit('ui.page_state.rendered', { route: entry.route, state: view, entry_kind: entry.kind });
    state.querySelector('[data-route]')?.addEventListener('click', (event) => { event.preventDefault(); select(entries.find(item => item.route === '/pages/new')); });
    state.querySelector('[data-retry]')?.addEventListener('click', () => select(entry));
  };
  const drawMenu = () => { list.innerHTML = entries.map(entry => `<button class="nav-item ${entry.kind === 'fixed' && entry.id === 'create-page' ? 'plus' : ''}" type="button" data-id="${entry.id}" aria-current="false"><span class="nav-icon" aria-hidden="true">${icons[entry.icon_key] || '•'}</span><span>${entry.title}</span></button>`).join(''); list.querySelectorAll('.nav-item').forEach(button => button.addEventListener('click', () => select(entries.find(entry => entry.id === button.dataset.id)))); };
  const markSelected = (entry) => list.querySelectorAll('.nav-item').forEach(button => button.setAttribute('aria-current', button.dataset.id === entry.id ? 'page' : 'false'));
  const select = async (entry) => {
    if (!entry) return;
    interactionId = crypto.randomUUID();
    if (location.pathname !== entry.route) history.pushState({}, '', entry.route);
    emit('ui.user_action', { route: entry.route, entry_kind: entry.kind });
    emit('ui.navigation.selected', { route: entry.route, entry_kind: entry.kind });
    markSelected(entry); state.innerHTML = '<section class="page-card"><p class="status">Loading destination…</p></section>';
    const started = performance.now();
    try {
      const response = await fetch(`/api/v1/pages${entry.route}`);
      if (!response.ok) throw new Error('temporary_failure');
      await response.json();
      emit('api.request.completed', { route: `/api/v1/pages${entry.route}`, duration: Math.round(performance.now() - started) });
      render(entry, 'ready');
      if (window.innerWidth < 672) { sidebar.classList.remove('open'); menuToggle.setAttribute('aria-expanded', 'false'); }
    } catch (error) {
      emit('api.request.failed', { route: `/api/v1/pages${entry.route}`, outcome:'failed', error_class:'temporary_failure' });
      emit('ui.navigation.failed', { route: entry.route, outcome:'failed', error_class:'temporary_failure' });
      render(entry, 'error', { message:'This destination is temporarily unavailable. Retry or choose another destination.' });
    }
  };
  const load = async () => {
    emit('ui.shell.loaded', { route:'/', state:'loading' });
    try {
      const response = await fetch(`/api/v1/navigation${location.search}`);
      if (!response.ok) throw new Error('temporary_failure');
      const data = await response.json(); entries = data.entries; drawMenu();
      emit('api.request.completed', { route:'/api/v1/navigation', count:entries.length });
      emit('ui.navigation.refreshed', { route:'/api/v1/navigation', count:entries.length });
      const requested = entries.find(entry => entry.route === location.pathname);
      if (requested) select(requested); else if (entries.some(entry => entry.kind === 'page')) select(entries.find(entry => entry.kind === 'page')); else render({ id:'empty', kind:'fixed', title:'Your dashboard', route:'/', icon_key:'spark' }, 'empty');
    } catch {
      drawMenu();
      list.innerHTML += '<div class="status error" role="alert">Saved pages are temporarily unavailable.<br><button class="retry" type="button" data-navigation-retry>Retry</button></div>';
      list.querySelector('[data-navigation-retry]').addEventListener('click', load);
      emit('api.request.failed', { route:'/api/v1/navigation', outcome:'failed', error_class:'temporary_failure' });
      emit('ui.navigation.failed', { route:'/api/v1/navigation', outcome:'failed', error_class:'temporary_failure' });
      render({ id:'empty', kind:'fixed', title:'Your dashboard', route:'/', icon_key:'spark' }, 'empty', { message:'Your saved pages are temporarily unavailable. You can still use Connected Tools, Memory, or create a page.' });
    }
  };
  menuToggle.addEventListener('click', () => { const open = !sidebar.classList.contains('open'); sidebar.classList.toggle('open', open); menuToggle.setAttribute('aria-expanded', String(open)); });
  load();
})();
