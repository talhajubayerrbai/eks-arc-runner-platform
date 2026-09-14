#!/usr/bin/env python3
"""
Validation Report Generator

Collects Surefire XML, JaCoCo XML, and k6 JSON output and produces
a single self-contained HTML report.

Usage:
    python generate_report.py \
        --surefire-dir app/build/test-results/test \
        --jacoco-xml   app/build/reports/jacoco/test/jacocoTestReport.xml \
        --k6-json      tests/k6/results.json \
        --output       report.html
"""
import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path


def parse_surefire(surefire_dir: str) -> dict:
    """Parse all Surefire XML files in a directory."""
    result = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0, "cases": []}
    directory = Path(surefire_dir)
    if not directory.exists():
        return result
    for xml_file in directory.glob("TEST-*.xml"):
        try:
            tree = ET.parse(xml_file)
            root = tree.getroot()
            result["tests"] += int(root.get("tests", 0))
            result["failures"] += int(root.get("failures", 0))
            result["errors"] += int(root.get("errors", 0))
            result["skipped"] += int(root.get("skipped", 0))
            for tc in root.findall("testcase"):
                status = "PASS"
                msg = ""
                if tc.find("failure") is not None:
                    status = "FAIL"
                    msg = tc.find("failure").get("message", "")[:200]
                elif tc.find("error") is not None:
                    status = "ERROR"
                    msg = tc.find("error").get("message", "")[:200]
                elif tc.find("skipped") is not None:
                    status = "SKIP"
                result["cases"].append({
                    "classname": tc.get("classname", ""),
                    "name": tc.get("name", ""),
                    "time": float(tc.get("time", 0)),
                    "status": status,
                    "message": msg,
                })
        except ET.ParseError as exc:
            print(f"Warning: could not parse {xml_file}: {exc}", file=sys.stderr)
    return result


def parse_jacoco(jacoco_xml: str) -> dict:
    """Parse JaCoCo XML report for line coverage."""
    result = {"line_covered": 0, "line_missed": 0, "branch_covered": 0, "branch_missed": 0}
    xml_path = Path(jacoco_xml)
    if not xml_path.exists():
        return result
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
        for counter in root.findall("counter"):
            ctype = counter.get("type")
            covered = int(counter.get("covered", 0))
            missed = int(counter.get("missed", 0))
            if ctype == "LINE":
                result["line_covered"] = covered
                result["line_missed"] = missed
            elif ctype == "BRANCH":
                result["branch_covered"] = covered
                result["branch_missed"] = missed
    except ET.ParseError as exc:
        print(f"Warning: could not parse JaCoCo XML: {exc}", file=sys.stderr)
    return result


def parse_k6(k6_json: str) -> dict:
    """Parse k6 JSON output (summary or NDJSON)."""
    result = {"p95": None, "p50": None, "avg": None, "max": None,
              "total_requests": None, "error_rate": None, "vus": 100, "duration": "30s"}
    json_path = Path(k6_json)
    if not json_path.exists():
        return result
    try:
        with open(json_path) as fh:
            # Try summary JSON first (single object)
            content = fh.read().strip()
            if content.startswith("{"):
                try:
                    data = json.loads(content)
                    metrics = data.get("metrics", {})
                    if "http_req_duration" in metrics:
                        vals = metrics["http_req_duration"]["values"]
                        result["p95"] = round(vals.get("p(95)", 0), 2)
                        result["p50"] = round(vals.get("p(50)", 0), 2)
                        result["avg"] = round(vals.get("avg", 0), 2)
                        result["max"] = round(vals.get("max", 0), 2)
                    if "http_reqs" in metrics:
                        result["total_requests"] = metrics["http_reqs"]["values"]["count"]
                    if "errors" in metrics:
                        result["error_rate"] = round(
                            metrics["errors"]["values"]["rate"] * 100, 2)
                    return result
                except json.JSONDecodeError:
                    pass
            # Fall back to NDJSON (one JSON object per line)
            lines = content.splitlines()
            durations = []
            for line in lines:
                try:
                    obj = json.loads(line)
                    if obj.get("type") == "Point" and obj.get("metric") == "http_req_duration":
                        durations.append(obj["data"]["value"])
                except (json.JSONDecodeError, KeyError):
                    continue
            if durations:
                durations.sort()
                result["total_requests"] = len(durations)
                result["avg"] = round(sum(durations) / len(durations), 2)
                result["max"] = round(max(durations), 2)
                idx_95 = int(len(durations) * 0.95)
                result["p95"] = round(durations[idx_95], 2)
                idx_50 = int(len(durations) * 0.50)
                result["p50"] = round(durations[idx_50], 2)
    except OSError as exc:
        print(f"Warning: could not read k6 JSON: {exc}", file=sys.stderr)
    return result


def slo_badge(value, threshold, unit="ms"):
    """Return a coloured badge string for HTML."""
    if value is None:
        return '<span class="badge badge-na">N/A</span>'
    colour = "badge-pass" if value < threshold else "badge-fail"
    return f'<span class="badge {colour}">{value}{unit}</span>'


def generate_html(surefire, jacoco, k6, output_path):
    """Write the HTML report."""
    total = surefire["tests"]
    passed = total - surefire["failures"] - surefire["errors"] - surefire["skipped"]
    fail_count = surefire["failures"] + surefire["errors"]

    # JaCoCo line coverage
    lc = jacoco["line_covered"] + jacoco["line_missed"]
    line_pct = round(jacoco["line_covered"] / lc * 100, 1) if lc > 0 else 0.0
    cov_colour = "badge-pass" if line_pct >= 70 else "badge-fail"

    # Test rows
    rows = ""
    for case in surefire["cases"]:
        status_cls = {
            "PASS": "status-pass", "FAIL": "status-fail",
            "ERROR": "status-fail", "SKIP": "status-skip"
        }.get(case["status"], "")
        rows += (
            f'<tr><td>{case["classname"]}</td><td>{case["name"]}</td>'
            f'<td class="{status_cls}">{case["status"]}</td>'
            f'<td>{case["time"]:.3f}s</td>'
            f'<td>{case["message"]}</td></tr>\n'
        )

    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    p95_badge = slo_badge(k6["p95"], 500)

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>EKS ARC Runner Platform — Validation Report</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #0d1117; color: #c9d1d9; margin: 0; padding: 24px; }}
    h1 {{ color: #58a6ff; }}
    h2 {{ color: #79c0ff; border-bottom: 1px solid #30363d; padding-bottom: 8px; }}
    .meta {{ color: #8b949e; font-size: 0.9em; margin-bottom: 24px; }}
    .cards {{ display: flex; gap: 16px; flex-wrap: wrap; margin-bottom: 32px; }}
    .card {{ background: #161b22; border: 1px solid #30363d; border-radius: 8px;
             padding: 20px; min-width: 180px; }}
    .card-title {{ color: #8b949e; font-size: 0.85em; margin-bottom: 8px; }}
    .card-value {{ font-size: 2em; font-weight: 700; }}
    .green {{ color: #3fb950; }} .red {{ color: #f85149; }} .yellow {{ color: #d29922; }}
    .badge {{ display: inline-block; padding: 2px 8px; border-radius: 12px;
              font-size: 0.85em; font-weight: 600; }}
    .badge-pass {{ background: #1f6feb; color: #cae8ff; }}
    .badge-fail {{ background: #5d1010; color: #ffa198; }}
    .badge-na   {{ background: #21262d; color: #8b949e; }}
    table {{ width: 100%; border-collapse: collapse; margin-bottom: 32px; font-size: 0.9em; }}
    th {{ background: #161b22; color: #8b949e; padding: 10px 12px; text-align: left;
          border-bottom: 2px solid #30363d; }}
    td {{ padding: 8px 12px; border-bottom: 1px solid #21262d; }}
    tr:hover td {{ background: #161b22; }}
    .status-pass {{ color: #3fb950; font-weight: 600; }}
    .status-fail {{ color: #f85149; font-weight: 600; }}
    .status-skip {{ color: #d29922; font-weight: 600; }}
  </style>
</head>
<body>
  <h1>EKS ARC Runner Platform — Validation Report</h1>
  <div class="meta">Generated: {now}</div>

  <h2>Summary</h2>
  <div class="cards">
    <div class="card">
      <div class="card-title">Tests Passed</div>
      <div class="card-value {'green' if fail_count == 0 else 'red'}">{passed}/{total}</div>
    </div>
    <div class="card">
      <div class="card-title">Line Coverage</div>
      <div class="card-value {cov_colour}">{line_pct}%</div>
    </div>
    <div class="card">
      <div class="card-title">k6 p95 Latency</div>
      <div class="card-value">{p95_badge}</div>
    </div>
    <div class="card">
      <div class="card-title">Total Requests</div>
      <div class="card-value">{k6['total_requests'] or 'N/A'}</div>
    </div>
    <div class="card">
      <div class="card-title">Error Rate</div>
      <div class="card-value {'red' if (k6['error_rate'] or 0) > 1 else 'green'}">
        {k6['error_rate'] if k6['error_rate'] is not None else 'N/A'}%
      </div>
    </div>
  </div>

  <h2>JUnit Test Results</h2>
  <table>
    <thead><tr><th>Class</th><th>Test</th><th>Status</th><th>Time</th><th>Message</th></tr></thead>
    <tbody>
      {rows if rows else '<tr><td colspan="5">No test data found</td></tr>'}
    </tbody>
  </table>

  <h2>JaCoCo Coverage</h2>
  <table>
    <thead><tr><th>Metric</th><th>Covered</th><th>Missed</th><th>Total</th><th>Percentage</th></tr></thead>
    <tbody>
      <tr>
        <td>Lines</td>
        <td class="green">{jacoco['line_covered']}</td>
        <td class="{'red' if jacoco['line_missed'] > 0 else 'green'}">{jacoco['line_missed']}</td>
        <td>{lc}</td>
        <td><span class="badge {cov_colour}">{line_pct}%</span></td>
      </tr>
      <tr>
        <td>Branches</td>
        <td class="green">{jacoco['branch_covered']}</td>
        <td>{jacoco['branch_missed']}</td>
        <td>{jacoco['branch_covered'] + jacoco['branch_missed']}</td>
        <td>N/A</td>
      </tr>
    </tbody>
  </table>

  <h2>k6 Load Test Results</h2>
  <p>Config: <strong>{k6['vus']} VUs</strong> × <strong>{k6['duration']}</strong> — SLO: p95 &lt; 500 ms</p>
  <table>
    <thead><tr><th>Metric</th><th>Value</th><th>SLO</th></tr></thead>
    <tbody>
      <tr><td>p95 Latency</td><td>{p95_badge}</td><td>&lt; 500 ms</td></tr>
      <tr><td>p50 Latency</td><td>{k6['p50']} ms</td><td>—</td></tr>
      <tr><td>Avg Latency</td><td>{k6['avg']} ms</td><td>—</td></tr>
      <tr><td>Max Latency</td><td>{k6['max']} ms</td><td>—</td></tr>
      <tr><td>Total Requests</td><td>{k6['total_requests']}</td><td>—</td></tr>
      <tr><td>Error Rate</td><td>{k6['error_rate']}%</td><td>&lt; 1%</td></tr>
    </tbody>
  </table>
</body>
</html>
"""

    with open(output_path, "w") as fh:
        fh.write(html)
    print(f"Report written to: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate validation HTML report")
    parser.add_argument("--surefire-dir", default="app/build/test-results/test")
    parser.add_argument("--jacoco-xml",
                        default="app/build/reports/jacoco/test/jacocoTestReport.xml")
    parser.add_argument("--k6-json", default="tests/k6/results.json")
    parser.add_argument("--output", default="report.html")
    args = parser.parse_args()

    surefire = parse_surefire(args.surefire_dir)
    jacoco = parse_jacoco(args.jacoco_xml)
    k6 = parse_k6(args.k6_json)

    generate_html(surefire, jacoco, k6, args.output)

    # Exit non-zero if JUnit failures exist
    if surefire["failures"] + surefire["errors"] > 0:
        print(f"ERROR: {surefire['failures'] + surefire['errors']} test failure(s) detected",
              file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
