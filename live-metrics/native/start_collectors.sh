#!/usr/bin/env bash
#
# Copyright (C) 2026 Intel Corporation.
# SPDX-License-Identifier: Apache-2.0
#
# Native replacement for supervisord: launches exactly the same three
# collector scripts Docker mode runs (docker/scripts/*), as plain background
# processes on the host, with no container involved.
set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-/tmp/results}"
PID_DIR="${RESULTS_DIR}/.pids"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../docker/scripts" && pwd)"

mkdir -p "${RESULTS_DIR}" "${PID_DIR}"
export RESULTS_DIR
export NPU_LOG="${NPU_LOG:-${RESULTS_DIR}/npu_usage.csv}"

echo "[start_collectors] RESULTS_DIR=${RESULTS_DIR}"

nohup bash "${SCRIPTS_DIR}/collect_platform.sh" >"${RESULTS_DIR}/platform_metrics.out" 2>&1 &
echo $! > "${PID_DIR}/platform.pid"
echo "[start_collectors] platform_metrics started (pid $(cat "${PID_DIR}/platform.pid"))"

nohup bash "${SCRIPTS_DIR}/collect_gpu.sh" >"${RESULTS_DIR}/gpu_metrics.out" 2>&1 &
echo $! > "${PID_DIR}/gpu.pid"
echo "[start_collectors] gpu_metrics started (pid $(cat "${PID_DIR}/gpu.pid"))"

nohup python3 "${SCRIPTS_DIR}/collect_npu.py" >"${RESULTS_DIR}/npu_usage.out" 2>&1 &
echo $! > "${PID_DIR}/npu.pid"
echo "[start_collectors] npu_usage started (pid $(cat "${PID_DIR}/npu.pid"))"

echo "[start_collectors] all collectors started. PIDs recorded in ${PID_DIR}"
