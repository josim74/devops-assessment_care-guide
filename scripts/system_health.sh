#!/usr/bin/env bash
# ==============================================================================
# system_health.sh - Production Linux System Health Monitoring Script
# ==============================================================================
# Collects CPU, memory, disk usage, load average, and top 5 memory processes.
# Supports configurable thresholds, JSON output, automated log rotation, and
# standard exit codes (0 = healthy, 1 = warning, 2 = critical/error).
# ==============================================================================
set -euo pipefail

# Default configuration values
DEFAULT_CPU_THRESHOLD=90
DEFAULT_MEM_THRESHOLD=85
DEFAULT_DISK_THRESHOLD=80
CRITICAL_THRESHOLD=95
MAX_LOG_SIZE_BYTES=10485760 # 10 MB

CPU_THRESHOLD="${DEFAULT_CPU_THRESHOLD}"
MEM_THRESHOLD="${DEFAULT_MEM_THRESHOLD}"
DISK_THRESHOLD="${DEFAULT_DISK_THRESHOLD}"
OUTPUT_JSON=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/health_log.txt"

show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Production server health monitoring script.

Options:
  --cpu PERCENT      CPU usage warning threshold (default: ${DEFAULT_CPU_THRESHOLD}%)
  --mem PERCENT      Memory usage warning threshold (default: ${DEFAULT_MEM_THRESHOLD}%)
  --disk PERCENT     Disk usage warning threshold for any mounted fs (default: ${DEFAULT_DISK_THRESHOLD}%)
  --log PATH         Custom log file path (default: ${LOG_FILE})
  --json             Output health report in structured JSON format
  -h, --help         Show this help message and exit

Exit Codes:
  0 = Healthy (All system metrics below warning thresholds)
  1 = Warning (One or more metrics exceeded warning thresholds)
  2 = Critical / Error (Critical thresholds exceeded >= 95% or command failure)
EOF
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu)
      CPU_THRESHOLD="$2"
      shift 2
      ;;
    --mem)
      MEM_THRESHOLD="$2"
      shift 2
      ;;
    --disk)
      DISK_THRESHOLD="$2"
      shift 2
      ;;
    --log)
      LOG_FILE="$2"
      shift 2
      ;;
    --json)
      OUTPUT_JSON=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Error: Unknown argument '$1'" >&2
      show_help >&2
      exit 2
      ;;
  esac
done

# Validate threshold parameters are integers between 1 and 100
for val in "${CPU_THRESHOLD}" "${MEM_THRESHOLD}" "${DISK_THRESHOLD}"; do
  if ! [[ "$val" =~ ^[0-9]+$ ]] || [ "$val" -lt 1 ] || [ "$val" -gt 100 ]; then
    echo "Error: Threshold must be an integer between 1 and 100 (got: $val)" >&2
    exit 2
  fi
done

# ------------------------------------------------------------------------------
# 1. Metric Collection
# ------------------------------------------------------------------------------
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# CPU Usage collection (Linux /proc/stat or top fallback for Darwin/macOS)
if [ -f /proc/stat ]; then
  # Read two snapshots to calculate actual CPU delta
  CPU_LINE1=$(grep '^cpu ' /proc/stat)
  sleep 0.5
  CPU_LINE2=$(grep '^cpu ' /proc/stat)

  IDLE1=$(echo "$CPU_LINE1" | awk '{print $5}')
  TOTAL1=$(echo "$CPU_LINE1" | awk '{print $2+$3+$4+$5+$6+$7+$8}')
  IDLE2=$(echo "$CPU_LINE2" | awk '{print $5}')
  TOTAL2=$(echo "$CPU_LINE2" | awk '{print $2+$3+$4+$5+$6+$7+$8}')

  DIFF_IDLE=$((IDLE2 - IDLE1))
  DIFF_TOTAL=$((TOTAL2 - TOTAL1))
  if [ "$DIFF_TOTAL" -gt 0 ]; then
    CPU_USAGE=$(( (1000 * (DIFF_TOTAL - DIFF_IDLE) / DIFF_TOTAL + 5) / 10 ))
  else
    CPU_USAGE=0
  fi
else
  # macOS / BSD fallback via ps %cpu normalized by core count
  NUM_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
  RAW_CPU=$(ps -A -o %cpu | awk '{s+=$1} END {printf("%d", s)}')
  CPU_USAGE=$(( RAW_CPU / NUM_CORES ))
fi

# Memory Usage collection
if command -v free > /dev/null 2>&1; then
  MEM_USAGE=$(free | awk '/Mem:/ {printf("%d", ($3/$2)*100)}')
else
  # macOS fallback using vm_stat
  MEM_USAGE=$(ps -A -o %mem | awk '{s+=$1} END {printf("%d", s)}')
fi

# Disk Usage: highest usage percentage among all mounted real filesystems
MAX_DISK_USAGE=0
DISK_DETAILS=""
while read -r pct mount; do
  clean_pct="${pct%\%}"
  if [[ "$clean_pct" =~ ^[0-9]+$ ]]; then
    if [ "$clean_pct" -gt "$MAX_DISK_USAGE" ]; then
      MAX_DISK_USAGE="$clean_pct"
    fi
    DISK_DETAILS="${DISK_DETAILS}  - ${mount}: ${clean_pct}%\n"
  fi
done < <(df -kP | awk 'NR>1 && $1 !~ /^(tmpfs|udev|none|devfs|overlay)$/ {print $5, $6}')

# Load Average collection (handles both Linux 'load average:' and macOS 'load averages:')
LOAD_AVG=$(uptime | awk -F'load average[s]?: ' '{print $2}' | sed 's/^[ \t]*//')

# Top 5 processes by memory consumption (PID, USER, %MEM, COMMAND)
TOP_5_MEM_RAW=$(ps -eo pid,user,%mem,comm -r 2>/dev/null || ps -eo pid,user,%mem,comm --sort=-%mem)
TOP_5_MEM=$(sed -n '1,6p' <<< "$TOP_5_MEM_RAW")

# ------------------------------------------------------------------------------
# 2. Evaluate Thresholds & Exit Codes
# ------------------------------------------------------------------------------
EXIT_CODE=0
WARNINGS=()

# Evaluate CPU
if [ "$CPU_USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
  EXIT_CODE=2
  WARNINGS+=("CRITICAL: CPU usage is at ${CPU_USAGE}% (Threshold: ${CRITICAL_THRESHOLD}%)")
elif [ "$CPU_USAGE" -ge "$CPU_THRESHOLD" ]; then
  [ "$EXIT_CODE" -lt 1 ] && EXIT_CODE=1
  WARNINGS+=("WARNING: CPU usage is at ${CPU_USAGE}% (Threshold: ${CPU_THRESHOLD}%)")
fi

# Evaluate Memory
if [ "$MEM_USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
  EXIT_CODE=2
  WARNINGS+=("CRITICAL: Memory usage is at ${MEM_USAGE}% (Threshold: ${CRITICAL_THRESHOLD}%)")
elif [ "$MEM_USAGE" -ge "$MEM_THRESHOLD" ]; then
  [ "$EXIT_CODE" -lt 1 ] && EXIT_CODE=1
  WARNINGS+=("WARNING: Memory usage is at ${MEM_USAGE}% (Threshold: ${MEM_THRESHOLD}%)")
fi

# Evaluate Disk
if [ "$MAX_DISK_USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
  EXIT_CODE=2
  WARNINGS+=("CRITICAL: Max disk usage is at ${MAX_DISK_USAGE}% (Threshold: ${CRITICAL_THRESHOLD}%)")
elif [ "$MAX_DISK_USAGE" -ge "$DISK_THRESHOLD" ]; then
  [ "$EXIT_CODE" -lt 1 ] && EXIT_CODE=1
  WARNINGS+=("WARNING: Max disk usage is at ${MAX_DISK_USAGE}% (Threshold: ${DISK_THRESHOLD}%)")
fi

# ------------------------------------------------------------------------------
# 3. Optional Bonus: Webhook Alert Routing (Slack / Discord)
# ------------------------------------------------------------------------------
send_webhook_alert() {
  local webhook_url="${ALERT_WEBHOOK_URL:-${SLACK_WEBHOOK_URL:-${DISCORD_WEBHOOK_URL:-}}}"
  if [ -n "$webhook_url" ] && [ ${#WARNINGS[@]} -gt 0 ]; then
    local payload
    local msg="⚠️ *System Health Alert* on \`$(hostname)\` at \`${TIMESTAMP}\`:\n"
    for w in "${WARNINGS[@]}"; do
      msg="${msg}• ${w}\n"
    done
    payload=$(jq -n --arg text "$msg" '{text: $text, content: $text}')
    curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$webhook_url" >/dev/null 2>&1 || true
  fi
}

send_webhook_alert

# ------------------------------------------------------------------------------
# 4. Automated Log Rotation
# ------------------------------------------------------------------------------
rotate_log_if_needed() {
  local log_path="$1"
  if [ -f "$log_path" ]; then
    local size
    size=$(wc -c < "$log_path" | tr -d ' ')
    if [ "$size" -gt "$MAX_LOG_SIZE_BYTES" ]; then
      [ -f "${log_path}.2" ] && mv -f "${log_path}.2" "${log_path}.3"
      [ -f "${log_path}.1" ] && mv -f "${log_path}.1" "${log_path}.2"
      mv -f "$log_path" "${log_path}.1"
      touch "$log_path"
    fi
  fi
}

mkdir -p "$(dirname "$LOG_FILE")"
rotate_log_if_needed "$LOG_FILE"

# ------------------------------------------------------------------------------
# 4. Format Output (Text or JSON) and Append to Log
# ------------------------------------------------------------------------------
if [ "$OUTPUT_JSON" = true ]; then
  # JSON array for warnings
  WARN_JSON="[]"
  if [ ${#WARNINGS[@]} -gt 0 ]; then
    WARN_JSON=$(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .)
  fi

  # Top processes JSON
  TOP_PROCS_JSON=$(awk 'NR>1 {printf("{\"pid\": \"%s\", \"user\": \"%s\", \"mem_pct\": \"%s\", \"cmd\": \"%s\"}\n", $1, $2, $3, $4)}' <<< "$TOP_5_MEM" | jq -s .)

  JSON_OUTPUT=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg status "$([ $EXIT_CODE -eq 0 ] && echo "healthy" || echo "unhealthy")" \
    --argjson exit_code "$EXIT_CODE" \
    --argjson cpu_pct "$CPU_USAGE" \
    --argjson mem_pct "$MEM_USAGE" \
    --argjson max_disk_pct "$MAX_DISK_USAGE" \
    --arg load_avg "$LOAD_AVG" \
    --argjson warnings "$WARN_JSON" \
    --argjson top_5_mem "$TOP_PROCS_JSON" \
    '{
      timestamp: $ts,
      status: $status,
      exit_code: $exit_code,
      cpu_usage_pct: $cpu_pct,
      memory_usage_pct: $mem_pct,
      max_disk_usage_pct: $max_disk_pct,
      load_average: $load_avg,
      warnings: $warnings,
      top_processes_by_mem: $top_5_mem
    }')

  echo "$JSON_OUTPUT"
  echo "$JSON_OUTPUT" >> "$LOG_FILE"
else
  # Human-readable formatted text
  REPORT="======================================================================
[${TIMESTAMP}] System Health Report (Status: $([ $EXIT_CODE -eq 0 ] && echo "HEALTHY" || echo "ATTENTION REQUIRED"))
======================================================================
CPU Usage:       ${CPU_USAGE}% (Threshold: ${CPU_THRESHOLD}%)
Memory Usage:    ${MEM_USAGE}% (Threshold: ${MEM_THRESHOLD}%)
Max Disk Usage:  ${MAX_DISK_USAGE}% (Threshold: ${DISK_THRESHOLD}%)
Load Average:    ${LOAD_AVG}

Disk Mounts:
$(echo -e -n "$DISK_DETAILS")
Top 5 Processes by Memory:
${TOP_5_MEM}
"
  if [ ${#WARNINGS[@]} -gt 0 ]; then
    REPORT="${REPORT}\nActive Warnings:\n"
    for w in "${WARNINGS[@]}"; do
      REPORT="${REPORT}[WARNING] ${w}\n"
    done
  fi
  REPORT="${REPORT}======================================================================\n"

  printf '%b\n' "$REPORT"
  printf '%b\n' "$REPORT" >> "$LOG_FILE"
fi

exit "$EXIT_CODE"
