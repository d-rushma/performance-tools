# live-metrics

A small, deployment-mode-agnostic HTTP API that turns the flat files written
by `docker/scripts/collect_platform.sh`, `collect_gpu.sh` and `collect_npu.py`
into a live, pollable JSON time series (CPU / GPU / NPU / memory / power).

`performance-tools` already had two ways to run those collectors:

- **Docker** (`docker/Dockerfile` + `docker/docker-compose.yaml`) — a privileged sidecar container running
  the three collectors under `supervisord`, for **offline benchmarking**
  (`benchmark-scripts/consolidate_multiple_run_of_metrics.py` parses the
  results *after* a run finishes).
- Nothing else — there was no bare-metal path and no live HTTP API.

`live-metrics/` adds both, without changing any existing behavior:

1. A **live HTTP API** (`metrics_api.py` / `metrics_parser.py`) that can be
   polled continuously (`GET /metrics`) while the collectors keep running —
   useful for a live dashboard, not just a one-shot benchmark report.
2. A **native (bare-metal) way to run the collectors**
   (`native/install_deps.sh`, `native/start_collectors.sh`,
   `native/stop_collectors.sh`) for consumers that don't want to run a
   privileged Docker container at all.

Both modes call **the exact same collector scripts** under `docker/scripts/`
and both are served by **the exact same `metrics_api.py`** — the only
difference is what starts the collectors (supervisord inside a container, or
a plain background process on the host) and where `$RESULTS_DIR` points.

## Running it

### Docker mode (opt-in, additive)

```bash
cd docker
log_dir=./results docker compose build   # picks up live-metrics/ automatically, see docker/Dockerfile
log_dir=./results docker compose up -d
curl http://localhost:9000/metrics | jq
```
`docker-compose.yaml` uses `network_mode: host`, so port 9000 is reachable
directly on the host once the container is up — no port publishing needed.

> This only applies when building the image locally (`docker-compose.yaml`).
> `docker-compose-reg.yaml` (the default `REGISTRY=true` path most consumers,
> including `loss-prevention`, use) still pulls the existing published
> `intel/retail-benchmark` tag, which does not yet include `live-metrics/` —
> that requires a new image tag to be published upstream. Until then,
> Docker-mode users on `REGISTRY=false` get it by building locally from this
> branch/fork.

### Native mode (no Docker/registry/compose at all)

```bash
make -C .. install-native          # one-time: installs sar/qmassa/PCM/etc. on the host
RESULTS_DIR=/tmp/my-session make -C .. start-native
RESULTS_DIR=/tmp/my-session make -C .. run-api-native   # foreground; Ctrl+C to stop
# ... in another shell, when the session ends:
RESULTS_DIR=/tmp/my-session make -C .. stop-native
```

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `RESULTS_DIR` | `/tmp/results` | Where the collectors write, and where `metrics_parser.py` reads from. |
| `NPU_LOG` | `${RESULTS_DIR}/npu_usage.csv` | Override if you need the NPU CSV somewhere else. |
| `METRICS_HTTP_PORT` | `9000` | Port `metrics_api.py` listens on. |
| `DEVICE_CONFIG_PATH` | unset | Optional path to a `KEY=VALUE` file for `GET /device-config`; returns `{}` if unset. |
| `QMASSA_CYCLE_SECONDS` | `0` (disabled) | If set > 0, `collect_gpu.sh` restarts qmassa every N seconds and deletes its output file first, keeping the JSON bounded for long-running live dashboards. `0` reproduces the original, unbounded, single-invocation behavior used by existing benchmarking consumers. |
| `METRICS_GPU_MAX_JSON_MB` | `256` | `build_gpu_series()` refuses to `json.load()` a qmassa file larger than this (defense in depth alongside `QMASSA_CYCLE_SECONDS`). |
| `METRICS_GPU_MAX_POINTS` | `300` | Caps how many qmassa samples are parsed per request (only the tail is ever plotted). |

## Endpoints

| Method & path | Returns |
|---|---|
| `GET /health` | `{"status": "ok"}` |
| `GET /metrics` | `{"cpu_utilization": [...], "gpu_utilization": [...], "npu_utilization": [...], "memory": [...], "power": [...]}` |
| `GET /platform-info` | `{"Processor", "iGPU", "NPU", "Memory", "Storage"}` |
| `GET /memory` | Latest single memory snapshot |
| `GET /device-config` | `{}` unless `DEVICE_CONFIG_PATH` is set (see above) |