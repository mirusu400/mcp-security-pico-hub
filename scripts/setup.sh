#!/bin/bash
# Quick setup script for Offensive Security MCP Servers

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

list_groups() {
    cat <<'EOF'
Available groups:
  all               Build the full hub
  web               Web security MCPs
  recon             Reconnaissance MCPs
  binary            Binary analysis MCPs
  aaos              AAOS/embedded workflow bundle
  osint             OSINT MCPs
  cloud             Cloud security MCPs
  blockchain        Blockchain security MCPs
  fuzzing           Fuzzing MCPs
  exploitation      Exploitation MCPs
  secrets           Secrets detection MCPs
  threat-intel      Threat intelligence MCPs
  active-directory  Active Directory MCPs
  password-cracking Password cracking MCPs
  code-security     Code security MCPs
  meta              Meta/security-tooling MCPs
EOF
}

usage() {
    cat <<'EOF'
Usage:
  bash scripts/setup.sh                    Build the full hub
  bash scripts/setup.sh web               Build only the web bundle
  bash scripts/setup.sh recon binary      Build multiple bundles
  bash scripts/setup.sh --list            List available bundles
  bash scripts/setup.sh -f FILE           Build a specific compose file
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
        --list)
            list_groups
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
    selected_groups=("all")
fi

if printf '%s\n' "${selected_groups[@]}" | grep -qx "all"; then
    compose_files=("${PROJECT_ROOT}/docker-compose.yml")
else
    for group in "${selected_groups[@]}"; do
        compose_files+=("$(compose_file_for_group "${group}")")
    done
fi

echo "=== Offensive Security MCP Servers Setup ==="
echo

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is not installed"
    exit 1
fi

echo "[+] Docker found: $(docker --version)"

if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo "Error: Docker Compose is not installed"
    exit 1
fi

echo "[+] Docker Compose found"
echo

for compose_file in "${compose_files[@]}"; do
    if [[ ! -f "${compose_file}" ]]; then
        echo "Error: compose file not found: ${compose_file}"
        exit 1
    fi
done

echo "[+] Building MCP server images..."
echo

for compose_file in "${compose_files[@]}"; do
    bundle_name="$(basename "${compose_file}")"
    echo "  Building bundle: ${bundle_name}"
    docker_compose -f "${compose_file}" build
    echo
done

echo "[+] Setup complete!"
echo
echo "Usage:"
echo "  bash scripts/setup.sh web          # Build only the web bundle"
echo "  bash scripts/setup.sh recon binary # Build multiple bundles"
echo "  docker compose -f docker-compose.web.yml up -d"
echo "  bash scripts/healthcheck.sh web"
echo
