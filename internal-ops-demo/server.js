const http = require('http');
const PORT = process.env.PORT || 3000;

const requests = [
  {
    id: 'REQ-1001',
    title: 'VPN access renewal',
    status: 'approved',
    owner: 'alex@company.com',
    createdAt: '2026-10-02T09:00:00Z'
  },
  {
    id: 'REQ-1002',
    title: 'New laptop setup',
    status: 'in_progress',
    owner: 'sam@company.com',
    createdAt: '2026-10-02T10:30:00Z'
  }
];

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'GET' && url.pathname === '/health') {
    res.statusCode = 200;
    res.end(JSON.stringify({ ok: true, app: 'internal-ops-demo', time: new Date().toISOString() }));
    return;
  }

  if (req.method === 'GET' && url.pathname === '/v1/requests') {
    res.statusCode = 200;
    res.end(JSON.stringify({ items: requests }));
    return;
  }

  if (req.method === 'GET' && url.pathname.startsWith('/v1/requests/')) {
    const id = url.pathname.split('/').pop();
    const request = requests.find(item => item.id === id);
    if (!request) {
      res.statusCode = 404;
      res.end(JSON.stringify({ error: 'Request not found' }));
      return;
    }
    res.statusCode = 200;
    res.end(JSON.stringify(request));
    return;
  }

  if (req.method === 'POST' && url.pathname === '/v1/requests') {
    const body = [];
    req.on('data', chunk => body.push(chunk));
    req.on('end', () => {
      try {
        const payload = JSON.parse(Buffer.concat(body).toString() || '{}');
        const created = {
          id: `REQ-${Math.floor(1000 + Math.random() * 9000)}`,
          title: payload.title || 'New request',
          status: payload.status || 'pending',
          owner: payload.owner || 'unknown@company.com',
          createdAt: new Date().toISOString()
        };
        requests.push(created);
        res.statusCode = 201;
        res.end(JSON.stringify(created));
      } catch (error) {
        res.statusCode = 400;
        res.end(JSON.stringify({ error: 'Invalid payload' }));
      }
    });
    return;
  }

  res.statusCode = 404;
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, () => {
  console.log(`Internal Ops demo app listening on http://localhost:${PORT}`);
});
