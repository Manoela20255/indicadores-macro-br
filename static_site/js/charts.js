// charts.js — live-updating charts: polls local plumber API and updates charts & preview tables.
(function(){
  const BASE = 'http://127.0.0.1:8000';
  const POLL_MS = 5 * 60 * 1000; // 5 minutes default; adjust as needed
  window.CHARTS = window.CHARTS || {};

  async function fetchJson(url, timeout = 7000){
    try{
      const controller = new AbortController();
      const id = setTimeout(() => controller.abort(), timeout);
      const res = await fetch(url, {signal: controller.signal});
      clearTimeout(id);
      if(!res.ok) throw new Error('HTTP ' + res.status);
      return await res.json();
    }catch(e){
      return null;
    }
  }

  function csvDataUri(header, rows){
    const csv = [header.join(','), ...rows.map(r=>r.join(','))].join('\n');
    return 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
  }

  function renderTable(containerId, headers, rows, maxRows = 50){
    const cont = document.getElementById(containerId);
    if(!cont) return;
    const table = document.createElement('table');
    table.className = 'preview-table';
    const thead = document.createElement('thead');
    const trh = document.createElement('tr');
    headers.forEach(h => { const th = document.createElement('th'); th.textContent = h; trh.appendChild(th); });
    thead.appendChild(trh);
    table.appendChild(thead);
    const tbody = document.createElement('tbody');
    const sliceRows = rows.slice(0, maxRows);
    sliceRows.forEach(r => {
      const tr = document.createElement('tr');
      r.forEach(c => { const td = document.createElement('td'); td.textContent = (c===null || c===undefined)?'':c; tr.appendChild(td); });
      tbody.appendChild(tr);
    });
    table.appendChild(tbody);
    cont.innerHTML = '';
    const note = document.createElement('div'); note.className = 'preview-note'; note.textContent = `Mostrando ${Math.min(rows.length, maxRows)} de ${rows.length} linhas.`;
    cont.appendChild(note);
    cont.appendChild(table);
  }

  function makeOrUpdateLine(id, labels, dataVals, label, color){
    const el = document.getElementById(id);
    if(!el) return null;
    if(!window.CHARTS[id]){
      const ctx = el.getContext('2d');
      window.CHARTS[id] = new Chart(ctx, {
        type: 'line',
        data: {labels: labels, datasets:[{label: label, data: dataVals, borderColor: color, backgroundColor: color+'33', tension:0.2}]},
        options: {plugins:{legend:{display:true}}, scales:{x:{display:true}, y:{display:true}}}
      });
      return window.CHARTS[id];
    } else {
      const ch = window.CHARTS[id];
      ch.data.labels = labels.slice();
      ch.data.datasets[0].data = dataVals.slice();
      ch.update();
      return ch;
    }
  }

  function updateDownloadLink(elId, header, rows){
    const el = document.getElementById(elId);
    if(!el) return;
    el.href = csvDataUri(header, rows);
  }

  function setLastUpdated(ts){
    const el = document.getElementById('last-updated');
    if(!el) return;
    el.textContent = ts.toLocaleString();
  }

  async function fetchAndUpdate(){
    // SELIC
    const s = await fetchJson(`${BASE}/selic?n=720`);
    if(s && Array.isArray(s)){
      const labels = s.map(r=>r.date);
      const vals = s.map(r=>Number(r.value));
      makeOrUpdateLine('chart-selic', labels, vals, 'SELIC', '#2b7bd3');
      const rows = labels.map((d,i)=>[d, vals[i]]);
      renderTable('table-selic', ['date','selic'], rows, 200);
      renderTable('table-bcb', ['date','selic'], rows, 200);
      updateDownloadLink('download-selic', ['date','selic'], rows);
    }

    // Focus
    const f = await fetchJson(`${BASE}/focus?n=240`);
    if(f && Array.isArray(f)){
      const labels = f.map(r=>r.date);
      const vals = f.map(r=>Number(r.value));
      makeOrUpdateLine('chart-focus', labels, vals, 'Expectativa IPCA', '#ff8c00');
      const rows = labels.map((d,i)=>[d, vals[i]]);
      renderTable('table-focus', ['date','focus_ipca'], rows, 200);
      updateDownloadLink('download-focus', ['date','focus_ipca'], rows);
    }

    // SIDRA IPCA
    const sd = await fetchJson(`${BASE}/sidra?n=240`);
    if(sd && Array.isArray(sd)){
      const labels = sd.map(r=>r.date);
      const vals = sd.map(r=>Number(r.value));
      makeOrUpdateLine('chart-sidra', labels, vals, 'IPCA (SIDRA)', '#2bd36a');
      const rows = labels.map((d,i)=>[d, vals[i]]);
      renderTable('table-ipca', ['date','ipca'], rows, 200);
      renderTable('table-sidra', ['date','ipca'], rows, 200);
      updateDownloadLink('download-sidra', ['date','ipca'], rows);
    }

    // IPEA sample
    const ip = await fetchJson(`${BASE}/ipea?n=240`);
    if(ip && Array.isArray(ip)){
      const labels = ip.map(r=>r$date);
      const vals = ip.map(r=>Number(r$value));
      makeOrUpdateLine('chart-ipea', labels, vals, 'IPEA (sample)', '#6a2bd3');
      const rows = labels.map((d,i)=>[d, vals[i]]);
      renderTable('table-ipea', ['date','ipea'], rows, 200);
      updateDownloadLink('download-ipea', ['date','ipea'], rows);
    }

    // Optionally update OECD/WB/IMF if present (attempt basic WB fetch)
    const wb = await fetchJson(`${BASE}/wbank?country=BR&indicator=NY.GDP.MKTP.CD&start=2000&end=2024`);
    if(wb && Array.isArray(wb)){
      const labels = wb.map(r=>r.date);
      const vals = wb.map(r=>Number(r.value));
      makeOrUpdateLine('chart-oecd', labels, vals, 'PIB (USD)', '#d3b12b');
      const rows = labels.map((d,i)=>[d, vals[i]]);
      renderTable('table-oecd', ['date','value'], rows, 200);
      updateDownloadLink('download-oecd', ['date','value'], rows);
    }

    // update last updated timestamp if any data arrived
    setLastUpdated(new Date());
  }

  // Initialize charts from existing window.* arrays or fallback sample data
  document.addEventListener('DOMContentLoaded', function(){
    // Initial render using available arrays (from data.js fallback or earlier fetch)
    if(window.SELIC_LABELS && window.SELIC_VALUES){
      makeOrUpdateLine('chart-selic', window.SELIC_LABELS, window.SELIC_VALUES, 'SELIC', '#2b7bd3');
      const rows = window.SELIC_LABELS.map((d,i)=>[d, window.SELIC_VALUES[i]]);
      renderTable('table-selic', ['date','selic'], rows, 100); renderTable('table-bcb', ['date','selic'], rows, 100);
      updateDownloadLink('download-selic', ['date','selic'], rows);
    }
    if(window.FOCUS_LABELS && window.FOCUS_VALUES){
      makeOrUpdateLine('chart-focus', window.FOCUS_LABELS, window.FOCUS_VALUES, 'Expectativa IPCA', '#ff8c00');
      const rows = window.FOCUS_LABELS.map((d,i)=>[d, window.FOCUS_VALUES[i]]);
      renderTable('table-focus', ['date','focus_ipca'], rows, 100); updateDownloadLink('download-focus', ['date','focus_ipca'], rows);
    }
    if(window.SIDRA_LABELS && window.SIDRA_VALUES){
      makeOrUpdateLine('chart-sidra', window.SIDRA_LABELS, window.SIDRA_VALUES, 'IPCA (SIDRA)', '#2bd36a');
      const rows = window.SIDRA_LABELS.map((d,i)=>[d, window.SIDRA_VALUES[i]]);
      renderTable('table-ipca', ['date','ipca'], rows, 100); renderTable('table-sidra', ['date','ipca'], rows, 100); updateDownloadLink('download-sidra', ['date','ipca'], rows);
    }
    if(window.IPEA_LABELS && window.IPEA_VALUES){
      makeOrUpdateLine('chart-ipea', window.IPEA_LABELS, window.IPEA_VALUES, 'IPEA (sample)', '#6a2bd3');
      const rows = window.IPEA_LABELS.map((d,i)=>[d, window.IPEA_VALUES[i]]);
      renderTable('table-ipea', ['date','ipea'], rows, 100); updateDownloadLink('download-ipea', ['date','ipea'], rows);
    }

    // Trigger immediate fetch to get fresh data and then poll periodically
    fetchAndUpdate().catch(err => console.warn('Initial fetch failed', err));
    setInterval(fetchAndUpdate, POLL_MS);
  });

  // Expose function to manually trigger an update from the console
  window.fetchAndUpdateCharts = fetchAndUpdate;

})();
