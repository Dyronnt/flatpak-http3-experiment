#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Conservative protocol evidence parser and valid-run timing summary."""
import argparse
from collections import Counter
import json
import pathlib
import re
import statistics


def protocol_evidence(text):
    responses = Counter(re.findall(r"^< HTTP/(1\.[01]|2|3)\s+([0-9]{3})\b", text, re.M))
    requests = re.findall(r"^> (?:GET|HEAD) (\S+) HTTP/(1\.[01]|2|3)\s*$", text, re.M)
    payload_requests = Counter(
        protocol for path, protocol in requests
        if re.search(r"/(?:objects|deltas)/", path)
    )
    return {
        "responses": {f"HTTP/{version} {status}": count for (version, status), count in sorted(responses.items())},
        "payload_requests": dict(sorted(payload_requests.items())),
        "http3_response_observed": any(version == "3" for version, _ in responses),
        "http3_success_response_observed": any(version == "3" and status.startswith("2") for version, status in responses),
        "http3_payload_request_observed": payload_requests["3"] > 0,
        "note": "Counts are log records, not byte shares. Concurrent responses cannot reliably be paired to URLs in this verbose format.",
    }


def summarize_runs(root):
    groups = {}
    invalid = []
    for path in sorted(root.glob("*/result.json")):
        run = json.loads(path.read_text())
        if run.get("valid") is not True:
            invalid.append({"run": path.parent.name, "reason": run.get("invalid_reason")})
            continue
        groups.setdefault(run["configuration"], []).append(run["elapsed_seconds"])
    return {
        "configurations": {
            name: {
                "n": len(values), "seconds": values,
                "median_seconds": statistics.median(values),
                "min_seconds": min(values), "max_seconds": max(values),
                "sample_stdev_seconds": statistics.stdev(values) if len(values) > 1 else None,
            } for name, values in groups.items()
        },
        "invalid_runs": invalid,
        "warning": "Descriptive statistics only; this does not establish a general HTTP/3 speedup.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--log", type=pathlib.Path)
    group.add_argument("--runs", type=pathlib.Path)
    parser.add_argument("--require-http3-payload", action="store_true")
    args = parser.parse_args()
    if args.require_http3_payload and not args.log:
        parser.error("--require-http3-payload requires --log")
    report = protocol_evidence(args.log.read_text(errors="replace")) if args.log else summarize_runs(args.runs)
    print(json.dumps(report, indent=2))
    if args.require_http3_payload and not (report["http3_success_response_observed"] and report["http3_payload_request_observed"]):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
