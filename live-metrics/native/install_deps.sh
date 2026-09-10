#!/usr/bin/env bash
#
# Copyright (C) 2026 Intel Corporation.
# SPDX-License-Identifier: Apache-2.0
#
# Bare-metal equivalent of the `RUN apt-get install ...` / `cargo install
# qmassa` / PCM-build steps in docker/Dockerfile. Idempotent -- safe to
# re-run; skips anything already installed.
#
# This does NOT touch anything under docker/ or affect Docker-mode users --
# it is only invoked by `make install-native` 

set -euo pipefail

echo "[install_deps] apt packages"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    sysstat iotop pciutils intel-gpu-tools \
    rustc cargo pkg-config libudev-dev udev \
    cmake build-essential git python3-pip python3-venv

if ! command -v qmassa >/dev/null 2>&1 && [ ! -x "$HOME/.cargo/bin/qmassa" ]; then
    echo "[install_deps] cargo install qmassa"
    cargo install qmassa --version 1.3.2 --locked
else
    echo "[install_deps] qmassa already installed, skipping"
fi

PCM_BIN_DIR="/opt/intel/pcm-bin"
if [ ! -x "${PCM_BIN_DIR}/bin/pcm" ]; then
    echo "[install_deps] building Intel PCM from source (this can take a few minutes)"
    tmp_dir=$(mktemp -d)
    git clone --recursive https://github.com/opcm/pcm.git "${tmp_dir}/pcm"
    (cd "${tmp_dir}/pcm" && mkdir build && cd build && cmake .. && cmake --build .)
    sudo mkdir -p "${PCM_BIN_DIR}/bin" "${PCM_BIN_DIR}/lib"
    sudo cp -r "${tmp_dir}/pcm/build/bin/." "${PCM_BIN_DIR}/bin/"
    sudo cp -r "${tmp_dir}/pcm/build/lib/." "${PCM_BIN_DIR}/lib/"
    rm -rf "${tmp_dir}"
else
    echo "[install_deps] Intel PCM already built, skipping"
fi

echo "[install_deps] python deps for the live-metrics API"
pip3 install --user -r "$(cd "$(dirname "$0")/.." && pwd)/requirements.txt"

echo "[install_deps] group membership for /dev/dri access (re-login required if just added)"
for grp in video render; do
    if getent group "$grp" >/dev/null 2>&1; then
        sudo usermod -aG "$grp" "$USER"
    fi
done

cat <<'EOF'
[install_deps] done.

Before relying on this in production, verify these are actually exposed on
your target SKU -- both vary by platform generation and are NOT guaranteed
by this script:

  find /sys/devices -iname 'npu_busy_time_us'
  ls /sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj

If group membership was just added above, log out and back in (or run
`newgrp video` / `newgrp render`) before starting the collectors.
EOF
