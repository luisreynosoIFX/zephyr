#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright The Zephyr Project Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Run Zephyr twister for PSOC Edge E84 (PSE84) Evaluation Kit.
#
# Usage:
#   ./run_twister_pse84.sh [OPTIONS]
#
# Options:
#   --core <core>           Target core: m55 | m33 | m33_ns | all  [default: m55]
#   --mode <mode>           Run mode: build | flash | build-flash-test [default: build]
#   --scope <scope>         Test scope: samples | tests | all       [default: all]
#   --jobs <N>              Parallel build jobs                     [default: 4]
#   --outdir <dir>          Output base directory (subdir per core) [default: auto]
#   --device-serial <port>  Serial device for flash mode            [default: /dev/ttyACM0]
#   --device-baud <baud>    Baud rate for flash mode                [default: 115200]
#   --no-summary            Skip generating the summary markdown
#   -h | --help             Show this help message
#
# Examples:
#   ./run_twister_pse84.sh --core m55 --mode build --scope all
#   ./run_twister_pse84.sh --core all --mode build --scope tests --jobs 8
#   ./run_twister_pse84.sh --core m55 --mode flash --scope samples \
#       --device-serial /dev/ttyACM0
#   ./run_twister_pse84.sh --core m55 --mode build-flash-test --scope samples \
#       --device-serial /dev/ttyACM0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZEPHYR_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ─── Defaults ─────────────────────────────────────────────────────────────────
CORES="m55"
MODE="build"
SCOPE="all"
JOBS=4
OUTDIR_BASE=""
DEVICE_SERIAL="/dev/ttyACM0"
DEVICE_BAUD="115200"
GENERATE_SUMMARY=true

# ─── Board targets ────────────────────────────────────────────────────────────
declare -A BOARD_TARGET=(
    [m55]="kit_pse84_eval/pse846gps2dbzc4a/m55"
    [m33]="kit_pse84_eval/pse846gps2dbzc4a/m33"
    [m33_ns]="kit_pse84_eval/pse846gps2dbzc4a/m33/ns"
)

# ─── Helpers ──────────────────────────────────────────────────────────────────
usage() {
    grep '^#' "${BASH_SOURCE[0]}" | grep -v '^#!/' | sed 's/^# \?//'
    exit 0
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --core)          CORES="$2";          shift 2 ;;
        --mode)          MODE="$2";           shift 2 ;;
        --scope)         SCOPE="$2";          shift 2 ;;
        --jobs)          JOBS="$2";           shift 2 ;;
        --outdir)        OUTDIR_BASE="$2";    shift 2 ;;
        --device-serial) DEVICE_SERIAL="$2";  shift 2 ;;
        --device-baud)   DEVICE_BAUD="$2";    shift 2 ;;
        --no-summary)    GENERATE_SUMMARY=false; shift ;;
        -h|--help)       usage ;;
        *) die "Unknown option: $1. Run with --help for usage." ;;
    esac
done

# ─── Validation ───────────────────────────────────────────────────────────────
case "${CORES}" in
    m55|m33|m33_ns) CORE_LIST=("${CORES}") ;;
    all)            CORE_LIST=(m55 m33 m33_ns) ;;
    *) die "--core must be: m55 | m33 | m33_ns | all (got '${CORES}')" ;;
esac

case "${MODE}" in
    build|flash|build-flash-test) ;;
    *) die "--mode must be: build | flash | build-flash-test (got '${MODE}')" ;;
esac

case "${SCOPE}" in
    samples|tests|all) ;;
    *) die "--scope must be: samples | tests | all (got '${SCOPE}')" ;;
esac

[[ "${JOBS}" =~ ^[1-9][0-9]*$ ]] || die "--jobs must be a positive integer (got '${JOBS}')"

if [[ ( "${MODE}" == "flash" || "${MODE}" == "build-flash-test" ) && ! -e "${DEVICE_SERIAL}" ]]; then
    printf 'WARNING: serial device %s not found — flash mode may fail.\n' \
        "${DEVICE_SERIAL}" >&2
fi

# ─── Locate west ──────────────────────────────────────────────────────────────
if command -v west &>/dev/null; then
    WEST="west"
elif [[ -x "${ZEPHYR_DIR}/../.venv/bin/west" ]]; then
    WEST="${ZEPHYR_DIR}/../.venv/bin/west"
else
    die "'west' not found in PATH and no .venv found. Activate your Zephyr venv first."
fi

# ─── Summary script path ──────────────────────────────────────────────────────
SUMMARIZE="${SCRIPT_DIR}/summarize_twister.py"

# ─── Timestamp ────────────────────────────────────────────────────────────────
TS="$(date '+%Y%m%d_%H%M%S')"

# ─── Build twister test directory arguments ───────────────────────────────────
build_test_dirs() {
    local scope="$1"
    case "${scope}" in
        samples) echo "-T samples" ;;
        tests)   echo "-T tests" ;;
        all)     echo "-T samples -T tests" ;;
    esac
}

# ─── Run twister for one core ──────────────────────────────────────────────────
run_core() {
    local core="$1"
    local board="${BOARD_TARGET[${core}]}"
    local run_outdir

    if [[ -n "${OUTDIR_BASE}" ]]; then
        run_outdir="${OUTDIR_BASE}/${core}"
    else
        run_outdir="${SCRIPT_DIR}/pse84_${core}_${TS}"
    fi

    printf '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    printf 'Board  : %s\n' "${board}"
    printf 'Mode   : %s\n' "${MODE}"
    printf 'Scope  : %s\n' "${SCOPE}"
    printf 'Output : %s\n' "${run_outdir}"
    printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'

    mkdir -p "${run_outdir}"

    local -a twister_args=(
        twister
        -p "${board}"
        --jobs "${JOBS}"
        -O "${run_outdir}"
    )

    read -ra dir_args <<< "$(build_test_dirs "${SCOPE}")"
    twister_args+=("${dir_args[@]}")

    if [[ "${MODE}" == "build" ]]; then
        twister_args+=(--build-only)

        printf 'Command: %s %s\n\n' "${WEST}" "${twister_args[*]}"
        (
            cd "${ZEPHYR_DIR}"
            "${WEST}" "${twister_args[@]}"
        )
    elif [[ "${MODE}" == "flash" ]]; then
        twister_args+=(
            --device-testing
            --device-serial "${DEVICE_SERIAL}"
            --device-baud "${DEVICE_BAUD}"
        )

        printf 'Command: %s %s\n\n' "${WEST}" "${twister_args[*]}"
        (
            cd "${ZEPHYR_DIR}"
            "${WEST}" "${twister_args[@]}"
        )
    else
        # build-flash-test: build first, flash+test only if build passes
        local build_args=("${twister_args[@]}" --build-only)
        printf '[Phase 1/2] Build\n'
        printf 'Command: %s %s\n\n' "${WEST}" "${build_args[*]}"

        local build_rc=0
        (
            cd "${ZEPHYR_DIR}"
            "${WEST}" "${build_args[@]}"
        ) || build_rc=$?

        if [[ "${build_rc}" -ne 0 ]]; then
            printf '\nERROR: Build phase failed (exit %d) — skipping flash+test.\n' \
                "${build_rc}" >&2
            return "${build_rc}"
        fi

        printf '\nBuild passed — proceeding to flash+test phase.\n'

        local test_args=(
            "${twister_args[@]}"
            --test-only
            --device-testing
            --device-serial "${DEVICE_SERIAL}"
            --device-baud "${DEVICE_BAUD}"
        )
        printf '[Phase 2/2] Flash + Test\n'
        printf 'Command: %s %s\n\n' "${WEST}" "${test_args[*]}"

        local test_rc=0
        (
            cd "${ZEPHYR_DIR}"
            "${WEST}" "${test_args[@]}"
        ) || test_rc=$?

        if [[ "${test_rc}" -ne 0 ]]; then
            printf '\nERROR: Flash+test phase failed (exit %d).\n' \
                "${test_rc}" >&2
            return "${test_rc}"
        fi
    fi

    if [[ "${GENERATE_SUMMARY}" == true ]] && [[ -f "${SUMMARIZE}" ]]; then
        local json_path="${run_outdir}/twister.json"
        if [[ -f "${json_path}" ]]; then
            printf '\nGenerating summary markdown...\n'
            python3 "${SUMMARIZE}" "${json_path}"
        else
            printf 'WARNING: twister.json not found at %s — skipping summary.\n' \
                "${json_path}" >&2
        fi
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
printf 'PSE84 Twister Runner — %s\n' "${TS}"
printf 'Zephyr : %s\n' "${ZEPHYR_DIR}"
printf 'Cores  : %s\n' "${CORE_LIST[*]}"
printf 'Mode   : %s\n' "${MODE}"
printf 'Scope  : %s\n' "${SCOPE}"
printf 'Jobs   : %s\n' "${JOBS}"

for core in "${CORE_LIST[@]}"; do
    run_core "${core}"
done

printf '\nAll done.\n'
