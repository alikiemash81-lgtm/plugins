const API_BASE = 'http://localhost:3000';

const summaryCards = document.getElementById('summaryCards');
const reviewsList = document.getElementById('reviewsList');
const findingsList = document.getElementById('findingsList');
const refreshButton = document.getElementById('refreshButton');

async function fetchJson(url) {
  const response = await fetch(url, { headers: { Accept: 'application/json' } });
  if (!response.ok) {
    throw new Error(`Request failed: ${response.status}`);
  }
  return response.json();
}

function renderSummary(reviews, findings) {
  const openFindings = findings.filter(item => item.status === 'open').length;
  const highRisk = reviews.filter(item => item.risk === 'high').length;
  const evidenceCount = reviews.reduce((acc, item) => acc + (item.evidence?.length || 0), 0);

  const cards = [
    { label: 'Active reviews', value: reviews.length },
    { label: 'Open findings', value: openFindings },
    { label: 'High-risk items', value: highRisk },
    { label: 'Evidence files', value: evidenceCount }
  ];

  summaryCards.innerHTML = cards.map(card => `
    <article class="stat-card">
      <span class="label">${card.label}</span>
      <div class="value">${card.value}</div>
    </article>
  `).join('');
}

function renderReviews(reviews) {
  if (!reviews.length) {
    reviewsList.innerHTML = '<div class="empty-state">No reviews available.</div>';
    return;
  }

  reviewsList.innerHTML = reviews.map(review => `
    <article class="audit-item">
      <div class="item-topline">
        <span class="item-id">${review.id}</span>
        <span class="badge ${review.status}">${review.status}</span>
      </div>
      <h3 class="item-title">${review.title}</h3>
      <div class="meta-row">
        <span><strong>Owner:</strong> ${review.owner}</span>
        <span><strong>Due:</strong> ${review.dueDate}</span>
        <span><strong>Risk:</strong> <span class="badge ${review.risk}">${review.risk}</span></span>
      </div>
      <ul class="evidence-list">
        ${(review.evidence || []).map(file => `<li>${file}</li>`).join('')}
      </ul>
    </article>
  `).join('');
}

function renderFindings(findings) {
  if (!findings.length) {
    findingsList.innerHTML = '<div class="empty-state">No findings recorded.</div>';
    return;
  }

  findingsList.innerHTML = findings.map(item => `
    <article class="finding-item">
      <div class="item-topline">
        <span class="item-id">${item.id}</span>
        <span class="badge ${item.status}">${item.status}</span>
      </div>
      <h3 class="item-title">${item.title}</h3>
      <div class="meta-row">
        <span><strong>Review:</strong> ${item.reviewId}</span>
        <span><strong>Owner:</strong> ${item.owner}</span>
        <span><strong>Severity:</strong> <span class="badge ${item.severity}">${item.severity}</span></span>
      </div>
    </article>
  `).join('');
}

async function loadAuditData() {
  try {
    const [reviewsResponse, findingsResponse] = await Promise.all([
      fetchJson(`${API_BASE}/v1/reviews`),
      fetchJson(`${API_BASE}/v1/findings`)
    ]);

    const reviews = reviewsResponse.items || [];
    const findings = findingsResponse.items || [];

    renderSummary(reviews, findings);
    renderReviews(reviews);
    renderFindings(findings);
  } catch (error) {
    const message = `Unable to load audit data. ${error.message}`;
    summaryCards.innerHTML = `<div class="stat-card"><span class="label">Status</span><div class="value" style="font-size: 1rem;">${message}</div></div>`;
    reviewsList.innerHTML = '<div class="empty-state">The audit API is unavailable. Ensure the local API is running on port 3000.</div>';
    findingsList.innerHTML = '<div class="empty-state">No findings available.</div>';
  }
}

refreshButton.addEventListener('click', loadAuditData);
loadAuditData();
