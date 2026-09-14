/**
 * k6 Load Test — EKS ARC Runner Platform
 *
 * Target:   100 virtual users (VUs)
 * Duration: 30 seconds
 * SLO:      p95 response time < 500 ms
 *
 * Usage:
 *   k6 run --env APP_URL=http://<alb-hostname> tests/k6/load-test.js
 */
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const rootLatency = new Trend('root_latency', true);
const healthLatency = new Trend('health_latency', true);
const helloLatency = new Trend('hello_latency', true);

// Load test configuration
export const options = {
  // Ramp up to 100 VUs over 10s, hold for 20s, ramp down over 5s
  stages: [
    { duration: '10s', target: 100 },
    { duration: '20s', target: 100 },
    { duration: '5s',  target: 0   },
  ],
  thresholds: {
    // SLO: p95 must be below 500 ms
    http_req_duration: ['p(95)<500'],
    // Error rate must be below 1%
    errors: ['rate<0.01'],
    // Individual endpoint SLOs
    root_latency:   ['p(95)<500'],
    health_latency: ['p(95)<300'],
    hello_latency:  ['p(95)<500'],
  },
};

const BASE_URL = __ENV.APP_URL || 'http://localhost:8080';

export default function () {
  const headers = { 'Accept': 'application/json' };

  // Test root endpoint
  const rootRes = http.get(`${BASE_URL}/`, { headers });
  rootLatency.add(rootRes.timings.duration);
  const rootOk = check(rootRes, {
    'GET / — status 200':          (r) => r.status === 200,
    'GET / — has message field':   (r) => JSON.parse(r.body).message !== undefined,
    'GET / — correct message':     (r) => JSON.parse(r.body).message === 'EKS ARC Runner Platform',
    'GET / — p95 < 500ms':        (r) => r.timings.duration < 500,
  });
  errorRate.add(!rootOk);

  sleep(0.1);

  // Test health endpoint
  const healthRes = http.get(`${BASE_URL}/health`, { headers });
  healthLatency.add(healthRes.timings.duration);
  const healthOk = check(healthRes, {
    'GET /health — status 200':    (r) => r.status === 200,
    'GET /health — status UP':     (r) => JSON.parse(r.body).status === 'UP',
    'GET /health — service name':  (r) => JSON.parse(r.body).service === 'spring-boot-app',
    'GET /health — p95 < 300ms':  (r) => r.timings.duration < 300,
  });
  errorRate.add(!healthOk);

  sleep(0.1);

  // Test hello endpoint
  const helloRes = http.get(`${BASE_URL}/hello`, { headers });
  helloLatency.add(helloRes.timings.duration);
  const helloOk = check(helloRes, {
    'GET /hello — status 200':     (r) => r.status === 200,
    'GET /hello — has message':    (r) => JSON.parse(r.body).message !== undefined,
    'GET /hello — correct hello':  (r) => JSON.parse(r.body).message === 'Hello from EKS!',
    'GET /hello — p95 < 500ms':   (r) => r.timings.duration < 500,
  });
  errorRate.add(!helloOk);

  sleep(0.2);
}

// Summary handler — prints results to stdout in CI
export function handleSummary(data) {
  const p95 = data.metrics.http_req_duration
    ? data.metrics.http_req_duration.values['p(95)']
    : 'N/A';
  console.log(`\n=== k6 Load Test Summary ===`);
  console.log(`VUs: 100, Duration: 30s`);
  console.log(`p95 response time: ${typeof p95 === 'number' ? p95.toFixed(2) + 'ms' : p95}`);
  console.log(`Error rate: ${(data.metrics.errors ? data.metrics.errors.values.rate * 100 : 0).toFixed(2)}%`);
  console.log(`Requests total: ${data.metrics.http_reqs ? data.metrics.http_reqs.values.count : 0}`);
  return {};
}
