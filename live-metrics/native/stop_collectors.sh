#!/usr/bin/env bash
#
# Copyright (C) 2026 Intel Corporation.
# SPDX-License-Identifier: Apache-2.0
#
# Stops collectors started by start_collectors.sh for the same RESULTS_DIR.
set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-/tmp/results}"
PID_DIR="${RESULTS_DIR}/.pids"

if [ ! -d "${PID_DIR}" ]; then
    echo "[stop_collectors] no PID directory at ${PID_DIR} -- nothing to stop"
    exit 0
fi

for pidfile in "${PID_DIR}"/*.pid; do
    [ -f "${pidfile}" ] || continue
    pid=$(cat "${pidfile}")
    name=$(basename "${pidfile}" .pid)
    if kill -0 "${pid}" 2>/dev/null; then
        # Each collector script itself launches the real tool (sar/qmassa/pcm)
        # as a child process; stop the whole group, not just the wrapper shell.
        pkill -P "${pid}" 2>/dev/null || true
        kill "${pid}" 2>/dev/null || true
        echo "[stop_collectors] stopped ${name} (pid ${pid})"
    else
        echo "[stop_collectors] ${name} (pid ${pid}) was not running"
    fi
    rm -f "${pidfile}"
done

echo "[stop_collectors] done."
