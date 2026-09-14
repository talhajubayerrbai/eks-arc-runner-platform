/**
 * k6 Load Test — eks-arc-runner-platform
 * ----------------------------------------
 * Targets: all three application endpoints
 * Config : 10 VUs, 30-second constant load
 * SLO    : p95 response time < 500 ms, error rate < 1 %
 *
 * Run locally:
 *   APP_URL=http://your-alb-hostname k6 run tests/load/load-test.js
 *
 * Run in CI (validate.yml step 3):
 *   k6 run --env APP_URL=$APP_URL \
 *          --out json=tests/load/results.json \
 *          tests/load/load-test.js
 */
import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// ── Custom metrics ────────────────────────────────────────────────────────────
const errorRate  = new Rate('error_rate');
const rootTrend  = new Trend('response_time_root',   true);
const healthTrend = new Trend('response_time_health', true);
const helloTrend  = new Trend('response_time_hello',  true);

// ── Test configuration ──────────────────────────────────────────────────────────
export const options = {
  vus: 10,
  duration: '30s',

  thresholds: {
    // Overall p95 must be under 500 ms
    http_req_duration: ['p(95)<500'],
    // Per-endpoint p95
    response_time_root:   ['p(95)<500'],
    response_time_health: ['p(95)<500'],
    response_time_hello:  ['p(95)<500'],
    // Error rate must be under 1 %
    error_rate:           ['rate<0.01'],
    // All checks must pass
    checks:               ['rate>0.99'],
  },
};

// ── Resolve base URL from environment ───────────────────────────────────────────
const BASE_URL = (__ENV.APP_URL || 'http://localhost:8080').replace(/\/$/, '');

// ── Default function (executed by every VU each iteration) ───────────────────────
export default function () {
  // --- GET / ---
  group('GET /', () => {
    const res = http.get(`${BASE_URL}/`);
    rootTrend.add(res.timings.duration);
    const ok = check(res, {
      'GET / → 200':           (r) => r.status === 200,
      'GET / → has message':   (r) => {
        try { return JSON.parse(r.body).message !== undefined; }
        catch (_) { return false; }
      },
      'GET / → correct body':  (r) => {
        try { return JSON.parse(r.body).message === 'EKS ARC Runner Platform'; }
        catch (_) { return false; }
      },
    });
    errorRate.add(!ok);
  });

  sleep(0.1);

  // --- GET /health ---
  group('GET /health', () => {
    const res = http.get(`${BASE_URL}/health`);
    healthTrend.add(res.timings.duration);
    const ok = check(res, {
      'GET /health → 200':        (r) => r.status === 200,
      'GET /health → status UP':  (r) => {
        try { return JSON.parse(r.body).status === 'UP'; }
        catch (_) { return false; }
      },
      'GET /health → service key': (r) => {
        try { return JSON.parse(r.body).service === 'spring-boot-app'; }
        catch (_) { return false; }
      },
    });
    errorRate.add(!ok);
  });

  sleep(0.1);

  // --- GET /hello ---
  group('GET /hello', () => {
    const res = http.get(`${BASE_URL}/hello`);
    helloTrend.add(res.timings.duration);
    const ok = check(res, {
      'GET /hello → 200':         (r) => r.status === 200,
      'GET /hello → has message': (r) => {
        try { return JSON.parse(r.body).message !== undefined; }
        catch (_) { return false; }
      },
      'GET /hello → correct body': (r) => {
        try { return JSON.parse(r.body).message === 'Hello from EKS!'; }
        catch (_) { return false; }
      },
    });
    errorRate.add(!ok);
  });

  sleep(0.2);
}

// ── Summary handler ───────────────────────────────────────────────────────────────────
export function handleSummary(data) {
  // Emit the summary to stdout so CI can capture it
  return {
    stdout: JSON.stringify(data, null, 2),
  };
}
