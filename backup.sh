#!/usr/bin/env bash
set -euo pipefail

BACKUP_NAME="test_backup"
SRC="/home/synnefo/Documents/test"
DEST="/tmp/test1"

LOG_DIR="$HOME/backup_logs"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="${LOG_DIR}/${BACKUP_NAME}_${TIMESTAMP}.log"
ERR_FILE="${LOG_DIR}/${BACKUP_NAME}_${TIMESTAMP}.error.log"

echo "[$(date '+%F %T')] Starting backup: $BACKUP_NAME" | tee -a "$LOG_FILE"
echo "Source      : $SRC" | tee -a "$LOG_FILE"
echo "Destination : $DEST" | tee -a "$LOG_FILE"
echo "Log file    : $LOG_FILE" | tee -a "$LOG_FILE"
echo

# ⛔ Dependency checks
if ! command -v pv &>/dev/null; then
    echo "❌ ERROR: 'pv' not installed. Install using: sudo apt install pv" | tee -a "$LOG_FILE"
    exit 1
fi
if ! command -v tar &>/dev/null; then
    echo "❌ ERROR: 'tar' not installed." | tee -a "$LOG_FILE"
    exit 1
fi

# 📦 Calculate size
echo "🔍 Calculating total size..."
total_size=$(du -sb "$SRC" | awk '{print $1}')
echo "📦 Total size: $(numfmt --to=iec "$total_size")" | tee -a "$LOG_FILE"

mkdir -p "$DEST"

echo "🚀 Starting transfer with live progress..."
echo

run_backup() {
    # IMPORTANT:
    # - stdout of tar/pv/tar -> LOG_FILE
    # - stderr of tar (errors) -> LOG_FILE
    # - stderr of pv (progress bar) -> stays on terminal
    tar -C "$(dirname "$SRC")" -cf - "$(basename "$SRC")" 2>>"$LOG_FILE" \
    | pv -s "$total_size" \
    | tar -C "$DEST" -xf - 2>>"$LOG_FILE" >>"$LOG_FILE"
}

if run_backup; then
    echo                       # new line after pv bar
    echo "✔ Backup Completed Successfully!" | tee -a "$LOG_FILE"
    echo "Log stored at: $LOG_FILE"
else
    status=$?
    echo                       # ensure clean newline
    echo "❌ Backup FAILED (exit code $status)" | tee -a "$LOG_FILE"

    {
        echo "Backup name : $BACKUP_NAME"
        echo "Timestamp   : $TIMESTAMP"
        echo "Exit code   : $status"
        echo "Log file    : $LOG_FILE"
        echo
        echo "Last 50 log lines:"
        tail -n 50 "$LOG_FILE"
    } >"$ERR_FILE"

    echo "Error details written to: $ERR_FILE"
    exit "$status"
fi
