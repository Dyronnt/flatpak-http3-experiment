#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Time one invocation with a monotonic clock; preserve all exit codes and raw logs."""
import argparse
import datetime
import json
import os
import pathlib
import subprocess
import time

import importlib.util

spec = importlib.util.spec_from_file_location("protocol_summary", pathlib.Path(__file__).with_name("summarize-results.py"))
evidence_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence_module)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=pathlib.Path, required=True)
    parser.add_argument("--configuration", choices=("http2", "http3", "system"), required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--ref", required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("missing measured command")
    env = dict(os.environ)
    env.pop("OSTREE_TURBO_HTTP3", None)
    if args.configuration == "http3":
        env["OSTREE_TURBO_HTTP3"] = "1"
    env["OSTREE_DEBUG_HTTP"] = "1"
    started_utc = datetime.datetime.now(datetime.timezone.utc).isoformat()
    with (args.state / "stdout.txt").open("xb") as out, (args.state / "http.log").open("xb") as err:
        start = time.monotonic_ns()
        result = subprocess.run(command, stdout=out, stderr=err, env=env)
        elapsed = (time.monotonic_ns() - start) / 1_000_000_000
    check = subprocess.run([command[0], "info", "--user", "--show-commit", args.ref], env=env, text=True, capture_output=True)
    actual_commit = check.stdout.strip() if check.returncode == 0 else None
    evidence = evidence_module.protocol_evidence((args.state / "http.log").read_text(errors="replace"))
    reasons = []
    if result.returncode != 0:
        reasons.append(f"install exited {result.returncode}")
    if actual_commit != args.commit:
        reasons.append("installed commit differs or cannot be read")
    if args.configuration == "http3" and not (evidence["http3_success_response_observed"] and evidence["http3_payload_request_observed"]):
        reasons.append("no successful HTTP/3 response plus payload-request evidence")
    if args.configuration == "http2":
        if evidence["http3_response_observed"]:
            reasons.append("unexpected HTTP/3 response in control")
        if evidence["payload_requests"].get("2", 0) == 0 or evidence["responses"].get("HTTP/2 200", 0) == 0:
            reasons.append("no HTTP/2 payload evidence in control")
    record = {
        "schema_version": 1, "configuration": args.configuration,
        "started_utc": started_utc, "elapsed_seconds": elapsed,
        "command": command, "exit_code": result.returncode,
        "expected_commit": args.commit, "installed_commit": actual_commit,
        "valid": not reasons, "invalid_reason": "; ".join(reasons) or None,
        "protocol_evidence": evidence,
        "isolation": {key: env.get(key) for key in ("FLATPAK_USER_DIR", "FLATPAK_SYSTEM_DIR", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME")},
        "debug_logging": True,
    }
    with (args.state / "result.json").open("x") as output:
        json.dump(record, output, indent=2)
        output.write("\n")
    print(json.dumps({"elapsed_seconds": elapsed, "valid": not reasons, "invalid_reason": record["invalid_reason"]}))
    return 0 if not reasons else 1


if __name__ == "__main__":
    raise SystemExit(main())
