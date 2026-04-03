#!/usr/bin/env bash

set -u

# =========================
# Configuration
# =========================
DEVICE_KEY="${BARK_KEY:-}"
DEVICE_HOST="${BARK_URL:-api.day.app}"

DEFAULT_GROUP="shell"
DEFAULT_SOUND="bell"

LOG_DIR="${R_LOG_DIR:-$PWD}"
META_DIR="${R_META_DIR:-$HOME/.cache/r}"
JOB_DB="${META_DIR}/jobs.tsv"

TAIL_LINES="${R_TAIL_LINES:-20}"
TAIL_CHARS="${R_TAIL_CHARS:-1200}"
R_LANG="${R_LANG:-en}"

mkdir -p "$LOG_DIR" "$META_DIR"
touch "$JOB_DB"

# DB columns:
# 1  job_id
# 2  job_name
# 3  submitted_at
# 4  pid
# 5  wrapper
# 6  logfile
# 7  workdir
# 8  cmd
# 9  status
# 10 start_epoch
# 11 end_epoch

# =========================
# i18n
# =========================
lang_is_zh() {
    [ "${R_LANG:-en}" = "zh" ]
}

msg() {
    local key="$1"
    case "$key" in
        usage)
            if lang_is_zh; then
                cat <<'EOF'
用法:
  r [options] "command"
  r ls [-a]
  r tail <job|job_id> [-n lines]
  r kill <job|job_id>
  r rm <job|job_id>
  r rm -a
  r rm -aa

子命令:
  ls                     列出任务；默认只显示未完成的最新任务
  ls -a                  显示所有历史记录
  tail <job|job_id>      显示 <job> 最新一次运行的日志尾部，或 <job_id> 对应运行的日志尾部
  tail ... -n lines      显示日志最后 N 行
  kill <job|job_id>      杀掉 <job> 最新一次运行中的任务，或 <job_id> 对应任务
  rm <job|job_id>        删除 <job> 的所有记录，或删除 <job_id> 对应的单条记录
  rm -a                  删除所有已完成任务记录 (finished/failed/killed)
  rm -aa                 删除所有任务记录

提交参数:
  -n job_name            指定任务名
  -l logfile             指定日志文件名或路径
  -h                     显示帮助

说明:
  - 自动后台运行
  - 断开 SSH 后任务仍继续
  - 自动记录日志
  - 任务结束后发送 Bark 通知
  - Bark 通知中包含日志尾部
  - 每次运行都有唯一 job_id

示例:
  r -n matlab_us -l output_US_new.log "matlab -nodisplay -r 'run_all; exit'"
  r ls
  r ls -a
  r tail matlab_us
  r tail matlab_us -n 200
  r tail job_20260403_153000_12345 -n 100
  r kill matlab_us
  r rm matlab_us
  r rm -a
EOF
            else
                cat <<'EOF'
Usage:
  r [options] "command"
  r ls [-a]
  r tail <job|job_id> [-n lines]
  r kill <job|job_id>
  r rm <job|job_id>
  r rm -a
  r rm -aa

Subcommands:
  ls                     List jobs; by default only unfinished latest jobs are shown
  ls -a                  Show all historical records
  tail <job|job_id>      Show the log tail of the latest run for <job>, or the exact run for <job_id>
  tail ... -n lines      Show the last N lines of the log
  kill <job|job_id>      Kill the latest running instance of <job>, or the exact run for <job_id>
  rm <job|job_id>        Remove all records for <job>, or one exact record for <job_id>
  rm -a                  Remove all completed job records (finished/failed/killed)
  rm -aa                 Remove all job records

Submission options:
  -n job_name            Set the job name
  -l logfile             Set the log file name or path
  -h                     Show help

Notes:
  - Runs jobs in the background automatically
  - Jobs survive SSH disconnects
  - Logs are recorded automatically
  - Sends a Bark notification when the job finishes
  - The Bark notification includes the tail of the log
  - Each run gets a unique job_id

Examples:
  r -n matlab_us -l output_US_new.log "matlab -nodisplay -r 'run_all; exit'"
  r ls
  r ls -a
  r tail matlab_us
  r tail matlab_us -n 200
  r tail job_20260403_153000_12345 -n 100
  r kill matlab_us
  r rm matlab_us
  r rm -a
EOF
            fi
            ;;
        please_set_bark_key)
            if lang_is_zh; then echo "请先设置 BARK_KEY 环境变量。"; else echo "Please set the BARK_KEY environment variable first."; fi
            ;;
        no_jobs_found)
            if lang_is_zh; then echo "暂无任务记录。"; else echo "No jobs found."; fi
            ;;
        invalid_line_count)
            if lang_is_zh; then echo "无效的行数: $2"; else echo "Invalid line count: $2"; fi
            ;;
        job_not_found)
            if lang_is_zh; then echo "未找到任务: $2"; else echo "Job not found: $2"; fi
            ;;
        log_not_exist)
            if lang_is_zh; then echo "日志文件不存在: $2"; else echo "Log file does not exist: $2"; fi
            ;;
        job_not_running)
            if lang_is_zh; then echo "任务当前不是运行状态: $2"; else echo "Job is not currently running: $2"; fi
            ;;
        failed_terminate)
            if lang_is_zh; then echo "终止任务失败: $2"; else echo "Failed to terminate job: $2"; fi
            ;;
        job_terminated)
            if lang_is_zh; then echo "任务已终止: $2"; else echo "Job terminated: $2"; fi
            ;;
        pid_label)
            if lang_is_zh; then echo "PID"; else echo "PID"; fi
            ;;
        log_label)
            if lang_is_zh; then echo "日志"; else echo "Log"; fi
            ;;
        job_label)
            if lang_is_zh; then echo "任务"; else echo "Job"; fi
            ;;
        job_id_label)
            if lang_is_zh; then echo "任务ID"; else echo "Job ID"; fi
            ;;
        no_job_record_for_id)
            if lang_is_zh; then echo "未找到 job_id 对应记录: $2"; else echo "No job record found for job_id: $2"; fi
            ;;
        no_job_record_for_name)
            if lang_is_zh; then echo "未找到该任务名记录: $2"; else echo "No job records found for job name: $2"; fi
            ;;
        removed_job_record)
            if lang_is_zh; then echo "已删除任务记录: $2"; else echo "Removed job record: $2"; fi
            ;;
        removed_job_records_for)
            if lang_is_zh; then echo "已删除任务记录: $2"; else echo "Removed job records for: $2"; fi
            ;;
        removed_entries)
            if lang_is_zh; then echo "删除条数: $2"; else echo "Removed entries: $2"; fi
            ;;
        removed_completed_records)
            if lang_is_zh; then echo "已删除已完成任务记录。"; else echo "Removed completed job records."; fi
            ;;
        removed_all_records)
            if lang_is_zh; then echo "已删除全部任务记录。"; else echo "Removed all job records."; fi
            ;;
        job_submitted)
            if lang_is_zh; then echo "任务已提交。"; else echo "Job submitted."; fi
            ;;
        job_name_label)
            if lang_is_zh; then echo "任务名"; else echo "Job name"; fi
            ;;
        command_label)
            if lang_is_zh; then echo "命令"; else echo "Command"; fi
            ;;
        usage_tail)
            if lang_is_zh; then echo "用法: r tail <job|job_id> [-n lines]"; else echo "Usage: r tail <job|job_id> [-n lines]"; fi
            ;;
        usage_kill)
            if lang_is_zh; then echo "用法: r kill <job|job_id>"; else echo "Usage: r kill <job|job_id>"; fi
            ;;
        usage_rm)
            if lang_is_zh; then echo "用法: r rm <job|job_id> | r rm -a | r rm -aa"; else echo "Usage: r rm <job|job_id> | r rm -a | r rm -aa"; fi
            ;;
        unknown_option_tail)
            if lang_is_zh; then echo "tail 子命令未知选项: $2"; else echo "Unknown option for tail: $2"; fi
            ;;
        option_requires_arg)
            if lang_is_zh; then echo "选项 -$2 需要参数。"; else echo "Option -$2 requires an argument."; fi
            ;;
        unknown_option)
            if lang_is_zh; then echo "未知选项: -$2"; else echo "Unknown option: -$2"; fi
            ;;
        table_header_latest)
            if lang_is_zh; then
                printf "%-24s %-22s %-19s %-12s %-10s %-8s %s\n" "JOB" "JOB_ID" "SUBMITTED" "DURATION" "STATUS" "PID" "LOG"
            else
                printf "%-24s %-22s %-19s %-12s %-10s %-8s %s\n" "JOB" "JOB_ID" "SUBMITTED" "DURATION" "STATUS" "PID" "LOG"
            fi
            ;;
        bark_title_success)
            if lang_is_zh; then echo "任务成功: $2"; else echo "Job succeeded: $2"; fi
            ;;
        bark_title_failed)
            if lang_is_zh; then echo "任务失败($3): $2"; else echo "Job failed($3): $2"; fi
            ;;
        bark_log_not_found)
            if lang_is_zh; then echo "(日志文件不存在)"; else echo "(log file not found)"; fi
            ;;
        bark_tail_truncated)
            if lang_is_zh; then echo "...（仅显示最后 $2 个字符）"; else echo "... (showing only the last $2 characters)"; fi
            ;;
    esac
}

# =========================
# Helpers
# =========================
now_human() {
    date +"%Y-%m-%d %H:%M:%S"
}

safe_name() {
    echo "$1" | tr ' /:' '___'
}

ensure_bark_config() {
    if [ -z "${DEVICE_KEY:-}" ]; then
        msg please_set_bark_key
        exit 1
    fi
}

bark_api() {
    echo "https://${DEVICE_HOST}/${DEVICE_KEY}"
}

pid_alive() {
    local pid="$1"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

is_job_id() {
    local s="$1"
    [[ "$s" == job_* ]]
}

format_duration() {
    local total="${1:-0}"
    if ! [[ "$total" =~ ^[0-9]+$ ]]; then
        total=0
    fi

    local d h m s
    d=$(( total / 86400 ))
    h=$(( (total % 86400) / 3600 ))
    m=$(( (total % 3600) / 60 ))
    s=$(( total % 60 ))

    if [ "$d" -gt 0 ]; then
        printf "%dd%02dh%02dm%02ds" "$d" "$h" "$m" "$s"
    elif [ "$h" -gt 0 ]; then
        printf "%02dh%02dm%02ds" "$h" "$m" "$s"
    elif [ "$m" -gt 0 ]; then
        printf "%02dm%02ds" "$m" "$s"
    else
        printf "%02ds" "$s"
    fi
}

job_field() {
    local line="$1"
    local idx="$2"
    printf "%s\n" "$line" | awk -F '\t' -v i="$idx" '{print $i}'
}

job_runtime_status() {
    local line="$1"
    local db_status pid wrapper
    db_status="$(job_field "$line" 9)"
    pid="$(job_field "$line" 4)"
    wrapper="$(job_field "$line" 5)"

    if [ "$db_status" = "finished" ] || [ "$db_status" = "failed" ] || [ "$db_status" = "killed" ]; then
        echo "$db_status"
        return
    fi

    if pid_alive "$pid"; then
        echo "running"
        return
    fi

    if [ -n "$wrapper" ] && [ -f "$wrapper" ]; then
        echo "running"
        return
    fi

    echo "unknown"
}

compute_duration_seconds() {
    local line="$1"
    local start_epoch end_epoch status now
    start_epoch="$(job_field "$line" 10)"
    end_epoch="$(job_field "$line" 11)"
    status="$(job_runtime_status "$line")"
    now="$(date +%s)"

    if ! [[ "${start_epoch:-}" =~ ^[0-9]+$ ]]; then
        echo "0"
        return
    fi

    if [[ "${end_epoch:-}" =~ ^[0-9]+$ ]] && [ "$end_epoch" -ge "$start_epoch" ]; then
        echo $(( end_epoch - start_epoch ))
        return
    fi

    case "$status" in
        running|unknown|finished|failed|killed)
            if [ "$now" -ge "$start_epoch" ]; then
                echo $(( now - start_epoch ))
            else
                echo "0"
            fi
            ;;
        *)
            echo "0"
            ;;
    esac
}

db_add_job() {
    local job_id="$1"
    local job_name="$2"
    local submitted_at="$3"
    local pid="$4"
    local wrapper="$5"
    local logfile="$6"
    local workdir="$7"
    local cmd="$8"
    local status="$9"
    local start_epoch="${10}"
    local end_epoch="${11}"

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$job_id" "$job_name" "$submitted_at" "$pid" "$wrapper" "$logfile" "$workdir" "$cmd" "$status" "$start_epoch" "$end_epoch" >> "$JOB_DB"
}

db_get_line_by_job_id() {
    local job_id="$1"
    awk -F '\t' -v id="$job_id" '$1 == id {print; exit}' "$JOB_DB"
}

db_get_latest_line_by_job_name() {
    local job_name="$1"
    awk -F '\t' -v job="$job_name" '$2 == job {line=$0} END{if(line) print line}' "$JOB_DB"
}

db_get_target_line() {
    local target="$1"
    if is_job_id "$target"; then
        db_get_line_by_job_id "$target"
    else
        db_get_latest_line_by_job_name "$target"
    fi
}

refresh_db_runtime_statuses() {
    [ -s "$JOB_DB" ] || return 0

    local tmp="${JOB_DB}.tmp.refresh.$$"
    : > "$tmp"

    while IFS=$'\t' read -r job_id job submitted pid wrapper logfile workdir cmd status start_epoch end_epoch; do
        [ -n "${job_id:-}" ] || continue

        if [ "$status" = "running" ] || [ "$status" = "unknown" ]; then
            if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
                status="running"
            else
                if [ -f "${wrapper:-}" ]; then
                    status="running"
                else
                    status="unknown"
                fi
            fi
        fi

        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$job_id" "$job" "$submitted" "$pid" "$wrapper" "$logfile" "$workdir" "$cmd" "$status" "$start_epoch" "$end_epoch" >> "$tmp"
    done < "$JOB_DB"

    mv "$tmp" "$JOB_DB"
}

print_ls_latest_only() {
    if [ ! -s "$JOB_DB" ]; then
        msg no_jobs_found
        return
    fi

    msg table_header_latest

    tac "$JOB_DB" | awk -F '\t' '!seen[$2]++ {print}' | while IFS=$'\t' read -r job_id job submitted pid wrapper logfile workdir cmd db_status start_epoch end_epoch; do
        local line runtime duration_s duration_h
        line="$(db_get_line_by_job_id "$job_id")"
        runtime="$(job_runtime_status "$line")"

        if [ "$runtime" = "finished" ] || [ "$runtime" = "failed" ] || [ "$runtime" = "killed" ]; then
            continue
        fi

        duration_s="$(compute_duration_seconds "$line")"
        duration_h="$(format_duration "$duration_s")"

        printf "%-24s %-22s %-19s %-12s %-10s %-8s %s\n" "$job" "$job_id" "$submitted" "$duration_h" "$runtime" "$pid" "$logfile"
    done
}

print_ls_all_history() {
    if [ ! -s "$JOB_DB" ]; then
        msg no_jobs_found
        return
    fi

    msg table_header_latest

    tac "$JOB_DB" | while IFS=$'\t' read -r job_id job submitted pid wrapper logfile workdir cmd db_status start_epoch end_epoch; do
        [ -n "${job_id:-}" ] || continue
        local line runtime duration_s duration_h
        line="$(printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$job_id" "$job" "$submitted" "$pid" "$wrapper" "$logfile" "$workdir" "$cmd" "$db_status" "$start_epoch" "$end_epoch")"
        runtime="$(job_runtime_status "$line")"
        duration_s="$(compute_duration_seconds "$line")"
        duration_h="$(format_duration "$duration_s")"

        printf "%-24s %-22s %-19s %-12s %-10s %-8s %s\n" "$job" "$job_id" "$submitted" "$duration_h" "$runtime" "$pid" "$logfile"
    done
}

tail_job() {
    local target="$1"
    local lines="${2:-50}"
    local line logfile

    if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
        msg invalid_line_count "$lines"
        exit 1
    fi

    line="$(db_get_target_line "$target")"
    if [ -z "$line" ]; then
        msg job_not_found "$target"
        exit 1
    fi

    logfile="$(job_field "$line" 6)"
    if [ ! -f "$logfile" ]; then
        msg log_not_exist "$logfile"
        exit 1
    fi

    tail -n "$lines" "$logfile"
}

kill_job() {
    local target="$1"
    local line pid status logfile job_id job_name now_epoch

    line="$(db_get_target_line "$target")"
    if [ -z "$line" ]; then
        msg job_not_found "$target"
        exit 1
    fi

    job_id="$(job_field "$line" 1)"
    job_name="$(job_field "$line" 2)"
    pid="$(job_field "$line" 4)"
    logfile="$(job_field "$line" 6)"
    status="$(job_runtime_status "$line")"
    now_epoch="$(date +%s)"

    if [ "$status" != "running" ]; then
        msg job_not_running "$status"
        echo "$(msg job_label): $job_name"
        echo "$(msg job_id_label): $job_id"
        echo "$(msg log_label): $logfile"
        exit 1
    fi

    if kill -- -"$pid" 2>/dev/null; then
        :
    elif kill "$pid" 2>/dev/null; then
        :
    else
        msg failed_terminate "$job_name ($job_id, PID $pid)"
        exit 1
    fi

    local tmp="${JOB_DB}.tmp.kill.$$"
    awk -F '\t' -v OFS='\t' -v id="$job_id" -v end_epoch="$now_epoch" '
        $1 == id {$9 = "killed"; $11 = end_epoch}
        {print}
    ' "$JOB_DB" > "$tmp" && mv "$tmp" "$JOB_DB"

    msg job_terminated "$job_name"
    echo "$(msg job_id_label): $job_id"
    echo "$(msg pid_label): $pid"
    echo "$(msg log_label): $logfile"
}

rm_job_or_id() {
    local target="$1"
    local tmp="${JOB_DB}.tmp.rm.$$"
    local removed=0

    if [ ! -s "$JOB_DB" ]; then
        msg no_jobs_found
        return
    fi

    if is_job_id "$target"; then
        removed="$(awk -F '\t' -v id="$target" '$1 == id {c++} END{print c+0}' "$JOB_DB")"
        if [ "$removed" -eq 0 ]; then
            msg no_job_record_for_id "$target"
            exit 1
        fi

        awk -F '\t' -v OFS='\t' -v id="$target" '$1 != id {print}' "$JOB_DB" > "$tmp" && mv "$tmp" "$JOB_DB"
        msg removed_job_record "$target"
        msg removed_entries "$removed"
    else
        removed="$(awk -F '\t' -v job="$target" '$2 == job {c++} END{print c+0}' "$JOB_DB")"
        if [ "$removed" -eq 0 ]; then
            msg no_job_record_for_name "$target"
            exit 1
        fi

        awk -F '\t' -v OFS='\t' -v job="$target" '$2 != job {print}' "$JOB_DB" > "$tmp" && mv "$tmp" "$JOB_DB"
        msg removed_job_records_for "$target"
        msg removed_entries "$removed"
    fi
}

rm_finished_jobs() {
    local tmp="${JOB_DB}.tmp.rma.$$"
    local before after removed

    if [ ! -s "$JOB_DB" ]; then
        msg no_jobs_found
        return
    fi

    before="$(wc -l < "$JOB_DB" | tr -d ' ')"
    awk -F '\t' -v OFS='\t' '$9 != "finished" && $9 != "failed" && $9 != "killed" {print}' "$JOB_DB" > "$tmp" && mv "$tmp" "$JOB_DB"
    after="$(wc -l < "$JOB_DB" | tr -d ' ')"
    removed=$((before - after))

    msg removed_completed_records
    msg removed_entries "$removed"
}

rm_all_jobs() {
    local before
    if [ ! -s "$JOB_DB" ]; then
        msg no_jobs_found
        return
    fi

    before="$(wc -l < "$JOB_DB" | tr -d ' ')"
    : > "$JOB_DB"

    msg removed_all_records
    msg removed_entries "$before"
}

submit_job() {
    local job_name="$1"
    local logfile="$2"
    local cmd="$3"

    ensure_bark_config

    local timestamp hostname_short workdir safe_job job_id start_epoch
    timestamp="$(date +"%Y%m%d_%H%M%S")"
    hostname_short="$(hostname)"
    workdir="$(pwd)"
    start_epoch="$(date +%s)"

    if [ -z "$job_name" ]; then
        job_name="job_${timestamp}"
    fi

    safe_job="$(safe_name "$job_name")"
    job_id="job_${timestamp}_$$"

    if [ -z "$logfile" ]; then
        logfile="${LOG_DIR}/${safe_job}_${timestamp}.log"
    else
        case "$logfile" in
            /*) ;;
            *) logfile="${workdir}/${logfile}" ;;
        esac
    fi

    local wrapper pidfile wrapper_pid submitted_at api
    wrapper="${META_DIR}/r_${safe_job}_${timestamp}_$$.sh"
    pidfile="${META_DIR}/${job_id}.pid"
    submitted_at="$(now_human)"
    api="$(bark_api)"

    cat > "$wrapper" <<EOF
#!/usr/bin/env bash
set -u

R_LANG=$(printf '%q' "$R_LANG")
START_TIME=\$(date +%s)
START_HUMAN=\$(date +"%Y-%m-%d %H:%M:%S")

JOB_ID=$(printf '%q' "$job_id")
HOSTNAME_SHORT=$(printf '%q' "$hostname_short")
WORKDIR=$(printf '%q' "$workdir")
CMD=$(printf '%q' "$cmd")
LOGFILE=$(printf '%q' "$logfile")
JOB_NAME=$(printf '%q' "$job_name")
BARK_API=$(printf '%q' "$api")
DEFAULT_GROUP=$(printf '%q' "$DEFAULT_GROUP")
DEFAULT_SOUND=$(printf '%q' "$DEFAULT_SOUND")
TAIL_LINES=$(printf '%q' "$TAIL_LINES")
TAIL_CHARS=$(printf '%q' "$TAIL_CHARS")
JOB_DB=$(printf '%q' "$JOB_DB")
WRAPPER_PATH=$(printf '%q' "$wrapper")

lang_is_zh() { [ "\${R_LANG:-en}" = "zh" ]; }

if lang_is_zh; then
    TITLE_SUCCESS_PREFIX="任务成功: "
    TITLE_FAILED_PREFIX="任务失败"
    LOG_NOT_FOUND_TEXT="(日志文件不存在)"
    LOG_TAIL_LABEL="日志末尾:"
    HOST_LABEL="主机"
    DIR_LABEL="目录"
    JOB_LABEL="任务"
    JOB_ID_LABEL="任务ID"
    CMD_LABEL="命令"
    LOG_LABEL="日志"
    START_LABEL="开始"
    END_LABEL="结束"
    DURATION_LABEL="耗时"
    EXIT_CODE_LABEL="状态码"
    TRUNC_PREFIX="...（仅显示最后 "
    TRUNC_SUFFIX=" 个字符）"
else
    TITLE_SUCCESS_PREFIX="Job succeeded: "
    TITLE_FAILED_PREFIX="Job failed"
    LOG_NOT_FOUND_TEXT="(log file not found)"
    LOG_TAIL_LABEL="Log tail:"
    HOST_LABEL="Host"
    DIR_LABEL="Directory"
    JOB_LABEL="Job"
    JOB_ID_LABEL="Job ID"
    CMD_LABEL="Command"
    LOG_LABEL="Log"
    START_LABEL="Start"
    END_LABEL="End"
    DURATION_LABEL="Duration"
    EXIT_CODE_LABEL="Exit code"
    TRUNC_PREFIX="... (showing only the last "
    TRUNC_SUFFIX=" characters)"
fi

cd "\$WORKDIR" || exit 127

{
    echo "========== r job meta =========="
    echo "job_id: \$JOB_ID"
    echo "job_name: \$JOB_NAME"
    echo "host: \$HOSTNAME_SHORT"
    echo "workdir: \$WORKDIR"
    echo "start: \$START_HUMAN"
    echo "command: \$CMD"
    echo "================================"
    echo
} >> "\$LOGFILE"

bash -lc "\$CMD" >> "\$LOGFILE" 2>&1
STATUS=\$?

END_TIME=\$(date +%s)
END_HUMAN=\$(date +"%Y-%m-%d %H:%M:%S")
DURATION=\$((END_TIME - START_TIME))

{
    echo
    echo "========== r job end =========="
    echo "end: \$END_HUMAN"
    echo "duration: \${DURATION}s"
    echo "exit_code: \$STATUS"
    echo "================================"
} >> "\$LOGFILE"

if [ \$STATUS -eq 0 ]; then
    TITLE="\${TITLE_SUCCESS_PREFIX}\$JOB_NAME"
    FINAL_STATUS="finished"
else
    TITLE="\${TITLE_FAILED_PREFIX}(\$STATUS): \$JOB_NAME"
    FINAL_STATUS="failed"
fi

LOG_TAIL=""
if [ -f "\$LOGFILE" ]; then
    LOG_TAIL=\$(tail -n "\$TAIL_LINES" "\$LOGFILE" 2>/dev/null || true)
    if [ "\${#LOG_TAIL}" -gt "\$TAIL_CHARS" ]; then
        LOG_TAIL="\${TRUNC_PREFIX}\${TAIL_CHARS}\${TRUNC_SUFFIX}\n\${LOG_TAIL: -\$TAIL_CHARS}"
    fi
else
    LOG_TAIL="\$LOG_NOT_FOUND_TEXT"
fi

BODY=\$(cat <<EOM
\${HOST_LABEL}: \$HOSTNAME_SHORT
\${DIR_LABEL}: \$WORKDIR
\${JOB_LABEL}: \$JOB_NAME
\${JOB_ID_LABEL}: \$JOB_ID
\${CMD_LABEL}: \$CMD
\${LOG_LABEL}: \$LOGFILE
\${START_LABEL}: \$START_HUMAN
\${END_LABEL}: \$END_HUMAN
\${DURATION_LABEL}: \${DURATION}s
\${EXIT_CODE_LABEL}: \$STATUS

\${LOG_TAIL_LABEL}
\$LOG_TAIL
EOM
)

MAX_BODY_CHARS=2500
if [ "\${#BODY}" -gt "\$MAX_BODY_CHARS" ]; then
    BODY="\${BODY: -\$MAX_BODY_CHARS}"
fi

if command -v jq >/dev/null 2>&1; then
    TITLE_ENCODED=\$(printf "%s" "\$TITLE" | jq -sRr @uri)
    BODY_ENCODED=\$(printf "%s" "\$BODY" | jq -sRr @uri)
else
    TITLE_ENCODED=\$(python3 - <<PY
import urllib.parse
print(urllib.parse.quote("""\$TITLE"""))
PY
)
    BODY_ENCODED=\$(python3 - <<PY
import urllib.parse
print(urllib.parse.quote("""\$BODY"""))
PY
)
fi

curl -fsS "\${BARK_API}/\${TITLE_ENCODED}/\${BODY_ENCODED}?sound=\${DEFAULT_SOUND}&group=\${DEFAULT_GROUP}" >/dev/null 2>&1 || true

TMP_DB="\${JOB_DB}.tmp.\$\$"
awk -F '\t' -v OFS='\t' -v id="\$JOB_ID" -v status="\$FINAL_STATUS" -v end_epoch="\$END_TIME" '
    \$1 == id {\$9 = status; \$11 = end_epoch}
    {print}
' "\$JOB_DB" > "\$TMP_DB" && mv "\$TMP_DB" "\$JOB_DB"

rm -f "\$WRAPPER_PATH"
EOF

    chmod +x "$wrapper"

    if command -v setsid >/dev/null 2>&1; then
        nohup setsid "$wrapper" >/dev/null 2>&1 &
    else
        nohup "$wrapper" >/dev/null 2>&1 &
    fi

    wrapper_pid=$!
    echo "$wrapper_pid" > "$pidfile"
    disown "$wrapper_pid" 2>/dev/null || true

    db_add_job "$job_id" "$job_name" "$submitted_at" "$wrapper_pid" "$wrapper" "$logfile" "$workdir" "$cmd" "running" "$start_epoch" ""

    msg job_submitted
    echo "$(msg job_name_label): $job_name"
    echo "$(msg job_id_label): $job_id"
    echo "$(msg pid_label): $wrapper_pid"
    echo "$(msg log_label): $logfile"
    echo "$(msg command_label): $cmd"
}

# =========================
# Main
# =========================
if [ $# -ge 1 ]; then
    case "$1" in
        ls)
            refresh_db_runtime_statuses
            if [ "${2:-}" = "-a" ]; then
                print_ls_all_history
            else
                print_ls_latest_only
            fi
            exit 0
            ;;
        tail)
            if [ $# -lt 2 ]; then
                msg usage_tail
                exit 1
            fi

            tail_target="$2"
            tail_lines=50

            shift 2
            while [ $# -gt 0 ]; do
                case "$1" in
                    -n)
                        if [ $# -lt 2 ]; then
                            msg usage_tail
                            exit 1
                        fi
                        tail_lines="$2"
                        shift 2
                        ;;
                    *)
                        msg unknown_option_tail "$1"
                        msg usage_tail
                        exit 1
                        ;;
                esac
            done

            tail_job "$tail_target" "$tail_lines"
            exit 0
            ;;
        kill)
            if [ $# -lt 2 ]; then
                msg usage_kill
                exit 1
            fi
            kill_job "$2"
            exit 0
            ;;
        rm)
            if [ $# -lt 2 ]; then
                msg usage_rm
                exit 1
            fi
            case "$2" in
                -a)
                    rm_finished_jobs
                    ;;
                -aa)
                    rm_all_jobs
                    ;;
                *)
                    rm_job_or_id "$2"
                    ;;
            esac
            exit 0
            ;;
        -h|--help)
            msg usage
            exit 0
            ;;
    esac
fi

JOB_NAME=""
LOGFILE=""

while getopts ":n:l:h" opt; do
    case "$opt" in
        n) JOB_NAME="$OPTARG" ;;
        l) LOGFILE="$OPTARG" ;;
        h)
            msg usage
            exit 0
            ;;
        :)
            msg option_requires_arg "$OPTARG"
            exit 1
            ;;
        \?)
            msg unknown_option "$OPTARG"
            exit 1
            ;;
    esac
done

shift $((OPTIND - 1))

if [ $# -eq 0 ]; then
    msg usage
    exit 1
fi

CMD="$*"
submit_job "$JOB_NAME" "$LOGFILE" "$CMD"