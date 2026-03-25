#!/bin/bash
# Health check script for running MCP servers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose "$@"
    else
        docker compose "$@"
    fi
}

normalize_group() {
    case "$1" in
        all|full) echo "all" ;;
        web|web-security) echo "web" ;;
        recon|reconnaissance) echo "recon" ;;
        binary|binary-analysis) echo "binary" ;;
        aaos) echo "aaos" ;;
        osint) echo "osint" ;;
        cloud|cloud-security) echo "cloud" ;;
        blockchain) echo "blockchain" ;;
        fuzz|fuzzing) echo "fuzzing" ;;
        exploit|exploitation) echo "exploitation" ;;
        secrets) echo "secrets" ;;
        threat-intel|intel|threatintel) echo "threat-intel" ;;
        ad|active-directory|active_directory) echo "active-directory" ;;
        password|password-cracking|password_cracking) echo "password-cracking" ;;
        code|code-security|code_security) echo "code-security" ;;
        meta) echo "meta" ;;
        *) return 1 ;;
    esac
}

compose_file_for_group() {
    case "$1" in
        all) echo "${PROJECT_ROOT}/docker-compose.yml" ;;
        web) echo "${PROJECT_ROOT}/docker-compose.web.yml" ;;
        recon) echo "${PROJECT_ROOT}/docker-compose.recon.yml" ;;
        binary) echo "${PROJECT_ROOT}/docker-compose.binary.yml" ;;
        aaos) echo "${PROJECT_ROOT}/docker-compose.aaos.yml" ;;
        osint) echo "${PROJECT_ROOT}/docker-compose.osint.yml" ;;
        cloud) echo "${PROJECT_ROOT}/docker-compose.cloud.yml" ;;
        blockchain) echo "${PROJECT_ROOT}/docker-compose.blockchain.yml" ;;
        fuzzing) echo "${PROJECT_ROOT}/docker-compose.fuzzing.yml" ;;
        exploitation) echo "${PROJECT_ROOT}/docker-compose.exploitation.yml" ;;
        secrets) echo "${PROJECT_ROOT}/docker-compose.secrets.yml" ;;
        threat-intel) echo "${PROJECT_ROOT}/docker-compose.threat-intel.yml" ;;
        active-directory) echo "${PROJECT_ROOT}/docker-compose.active-directory.yml" ;;
        password-cracking) echo "${PROJECT_ROOT}/docker-compose.password-cracking.yml" ;;
        code-security) echo "${PROJECT_ROOT}/docker-compose.code-security.yml" ;;
        meta) echo "${PROJECT_ROOT}/docker-compose.meta.yml" ;;
        *) return 1 ;;
    esac
}

usage() {
    cat <<'EOF'
Usage:
  bash scripts/healthcheck.sh                    Check the full hub
  bash scripts/healthcheck.sh web               Check only the web bundle
  bash scripts/healthcheck.sh recon binary      Check multiple bundles
  bash scripts/healthcheck.sh -f FILE           Check a specific compose file
EOF
}

compose_files=()
selected_groups=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -f|--compose-file)
            if [[ $# -lt 2 ]]; then
                echo "Error: missing value for $1"
                exit 1
            fi
            compose_files+=("$2")
            shift 2
            ;;
        *)
            if ! normalized_group="$(normalize_group "$1")"; then
                echo "Error: unknown group '$1'"
                echo
                usage
                exit 1
            fi
            selected_groups+=("${normalized_group}")
            shift
            ;;
    esac
done

if [[ ${#compose_files[@]} -eq 0 && ${#selected_groups[@]} -eq 0 ]]; then
    compose_files=("${PROJECT_ROOT}/docker-compose.yml")
elif printf '%s\n' "${selected_groups[@]}" | grep -qx "all"; then
    compose_files=("${PROJECT_ROOT}/docker-compose.yml")
else
    for group in "${selected_groups[@]}"; do
        compose_files+=("$(compose_file_for_group "${group}")")
    done
fi

echo "=== MCP Server Health Check ==="
echo

for compose_file in "${compose_files[@]}"; do
    if [[ ! -f "${compose_file}" ]]; then
        echo "Error: compose file not found: ${compose_file}"
        exit 1
    fi

    bundle_name="$(basename "${compose_file}")"
    containers="$(docker_compose -f "${compose_file}" ps -q 2>/dev/null || true)"

    echo "[Bundle] ${bundle_name}"

    if [[ -z "${containers}" ]]; then
        echo "No MCP servers running"
        echo "Start with: docker compose -f ${bundle_name} up -d"
        echo
        continue
    fi

    echo "Running containers:"
    echo
    docker_compose -f "${compose_file}" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true

    echo
    echo "Health status:"
    echo

    for container in ${containers}; do
        name="$(docker inspect --format '{{.Name}}' "${container}" | sed 's/\///')"
        health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no healthcheck{{end}}' "${container}" 2>/dev/null || echo "unknown")"

        if [[ "${health}" == "healthy" ]]; then
            echo "  [OK] ${name}"
        elif [[ "${health}" == "unhealthy" ]]; then
            echo "  [FAIL] ${name}"
        elif [[ "${health}" == "starting" ]]; then
            echo "  [STARTING] ${name}"
        else
            echo "  [?] ${name} (${health})"
        fi
    done

    echo
done
