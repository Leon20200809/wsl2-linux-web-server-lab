#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# lg_job Exporter for NotebookLM
# WordPressのカスタム投稿 lg_job を
# NotebookLM向けの TSV / CSV に整形して出力する。
# ==========================================

DB_NAME="lg_job_hunter_lab"
POST_TYPE="lg_job"
OUT_DIR="$HOME/notebooklm-lg-job-export"

MYSQL_CMD=(sudo mysql -D "$DB_NAME" --batch --raw --default-character-set=utf8mb4)

HIDDEN_COMPANY_NAME="（事業所の意向により公開していません）"

log() {
  echo "[INFO] $*"
}

ok() {
  echo "[OK] $*"
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

# ------------------------------------------
# 事前確認
# ------------------------------------------

log "DB存在確認: $DB_NAME"

sudo mysql -e "USE \`$DB_NAME\`;" >/dev/null 2>&1 \
  || die "DBが見つかりません: $DB_NAME"

log "wp_posts / wp_postmeta 確認"

sudo mysql -D "$DB_NAME" -e "SHOW TABLES LIKE 'wp_posts';" | grep -q "wp_posts" \
  || die "wp_posts が見つかりません"

sudo mysql -D "$DB_NAME" -e "SHOW TABLES LIKE 'wp_postmeta';" | grep -q "wp_postmeta" \
  || die "wp_postmeta が見つかりません"

JOB_COUNT="$(
  sudo mysql -D "$DB_NAME" --batch --skip-column-names -e "
    SELECT COUNT(*)
    FROM wp_posts
    WHERE post_type = '$POST_TYPE';
  "
)"

ok "$POST_TYPE 件数: $JOB_COUNT"

mkdir -p "$OUT_DIR"
ok "出力フォルダ: $OUT_DIR"

# ------------------------------------------
# 1. 1行1求人の主力データ
# ------------------------------------------

log "出力中: lg_job_flat_for_notebooklm.tsv"

"${MYSQL_CMD[@]}" -e "
WITH pivoted AS (
  SELECT
    p.ID AS post_id,
    p.post_title,
    p.post_status,
    p.post_date,

    MAX(CASE WHEN pm.meta_key = '_lgjh_company_name' THEN pm.meta_value END) AS company_name_raw,
    MAX(CASE WHEN pm.meta_key = '_lgjh_location' THEN pm.meta_value END) AS location,
    MAX(CASE WHEN pm.meta_key = '_lgjh_job_number' THEN pm.meta_value END) AS job_number,
    MAX(CASE WHEN pm.meta_key = '_lgjh_job_url' THEN pm.meta_value END) AS job_url,
    MAX(CASE WHEN pm.meta_key = '_lgjh_salary' THEN pm.meta_value END) AS salary_raw,
    MAX(CASE WHEN pm.meta_key = '_lgjh_employment_type' THEN pm.meta_value END) AS employment_type,
    MAX(CASE WHEN pm.meta_key = '_lgjh_status' THEN pm.meta_value END) AS job_status,
    MAX(CASE WHEN pm.meta_key = '_lgjh_contact_person' THEN pm.meta_value END) AS contact_person,
    MAX(CASE WHEN pm.meta_key = '_lgjh_contact_email' THEN pm.meta_value END) AS contact_email,
    MAX(CASE WHEN pm.meta_key = '_lgjh_description' THEN pm.meta_value END) AS description

  FROM wp_posts p
  LEFT JOIN wp_postmeta pm
    ON p.ID = pm.post_id
  WHERE p.post_type = '$POST_TYPE'
  GROUP BY p.ID, p.post_title, p.post_status, p.post_date
)
SELECT
  post_id,

  REPLACE(REPLACE(REPLACE(COALESCE(post_title, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS post_title,
  post_status,
  post_date,

  REPLACE(REPLACE(REPLACE(COALESCE(company_name_raw, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS company_name_raw,

  CASE
    WHEN company_name_raw = '$HIDDEN_COMPANY_NAME' THEN 1
    ELSE 0
  END AS is_company_hidden,

  REPLACE(REPLACE(REPLACE(COALESCE(location, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS location,
  REPLACE(REPLACE(REPLACE(COALESCE(job_number, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS job_number,

  SUBSTRING_INDEX(COALESCE(job_number, ''), '-', 1) AS job_number_prefix,

  REPLACE(REPLACE(REPLACE(COALESCE(job_url, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS job_url,
  REPLACE(REPLACE(REPLACE(COALESCE(salary_raw, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS salary_raw,
  REPLACE(REPLACE(REPLACE(COALESCE(employment_type, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS employment_type,
  REPLACE(REPLACE(REPLACE(COALESCE(job_status, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS job_status,
  REPLACE(REPLACE(REPLACE(COALESCE(contact_person, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS contact_person,
  REPLACE(REPLACE(REPLACE(COALESCE(contact_email, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS contact_email,
  REPLACE(REPLACE(REPLACE(COALESCE(description, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS description

FROM pivoted
ORDER BY post_id DESC;
" > "$OUT_DIR/lg_job_flat_for_notebooklm.tsv"

ok "lg_job_flat_for_notebooklm.tsv"

# ------------------------------------------
# 2. 会社別求人数
# ------------------------------------------

log "出力中: company_count.tsv"

"${MYSQL_CMD[@]}" -e "
SELECT
  REPLACE(REPLACE(REPLACE(pm.meta_value, CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS company_name,
  COUNT(*) AS job_count
FROM wp_posts p
INNER JOIN wp_postmeta pm
  ON p.ID = pm.post_id
WHERE
  p.post_type = '$POST_TYPE'
  AND pm.meta_key = '_lgjh_company_name'
GROUP BY pm.meta_value
ORDER BY job_count DESC, company_name ASC;
" > "$OUT_DIR/company_count.tsv"

ok "company_count.tsv"

# ------------------------------------------
# 3. 会社名非公開求人だけ
# ------------------------------------------

log "出力中: hidden_company_jobs.tsv"

"${MYSQL_CMD[@]}" -e "
WITH pivoted AS (
  SELECT
    p.ID AS post_id,
    p.post_title,
    p.post_status,
    p.post_date,

    MAX(CASE WHEN pm.meta_key = '_lgjh_company_name' THEN pm.meta_value END) AS company_name_raw,
    MAX(CASE WHEN pm.meta_key = '_lgjh_location' THEN pm.meta_value END) AS location,
    MAX(CASE WHEN pm.meta_key = '_lgjh_job_number' THEN pm.meta_value END) AS job_number,
    MAX(CASE WHEN pm.meta_key = '_lgjh_job_url' THEN pm.meta_value END) AS job_url,
    MAX(CASE WHEN pm.meta_key = '_lgjh_salary' THEN pm.meta_value END) AS salary_raw,
    MAX(CASE WHEN pm.meta_key = '_lgjh_employment_type' THEN pm.meta_value END) AS employment_type,
    MAX(CASE WHEN pm.meta_key = '_lgjh_contact_person' THEN pm.meta_value END) AS contact_person,
    MAX(CASE WHEN pm.meta_key = '_lgjh_contact_email' THEN pm.meta_value END) AS contact_email,
    MAX(CASE WHEN pm.meta_key = '_lgjh_description' THEN pm.meta_value END) AS description

  FROM wp_posts p
  LEFT JOIN wp_postmeta pm
    ON p.ID = pm.post_id
  WHERE p.post_type = '$POST_TYPE'
  GROUP BY p.ID, p.post_title, p.post_status, p.post_date
)
SELECT
  post_id,

  REPLACE(REPLACE(REPLACE(COALESCE(post_title, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS post_title,
  post_date,

  REPLACE(REPLACE(REPLACE(COALESCE(location, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS location,
  REPLACE(REPLACE(REPLACE(COALESCE(job_number, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS job_number,

  SUBSTRING_INDEX(COALESCE(job_number, ''), '-', 1) AS job_number_prefix,

  REPLACE(REPLACE(REPLACE(COALESCE(salary_raw, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS salary_raw,
  REPLACE(REPLACE(REPLACE(COALESCE(employment_type, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS employment_type,
  REPLACE(REPLACE(REPLACE(COALESCE(contact_person, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS contact_person,
  REPLACE(REPLACE(REPLACE(COALESCE(contact_email, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS contact_email,
  REPLACE(REPLACE(REPLACE(COALESCE(job_url, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS job_url,
  REPLACE(REPLACE(REPLACE(COALESCE(description, ''), CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' ') AS description

FROM pivoted
WHERE company_name_raw = '$HIDDEN_COMPANY_NAME'
ORDER BY post_id DESC;
" > "$OUT_DIR/hidden_company_jobs.tsv"

ok "hidden_company_jobs.tsv"

# ------------------------------------------
# 4. メタキー一覧
# ------------------------------------------

log "出力中: meta_keys.tsv"

"${MYSQL_CMD[@]}" -e "
SELECT
  pm.meta_key,
  COUNT(*) AS count
FROM wp_postmeta pm
INNER JOIN wp_posts p
  ON p.ID = pm.post_id
WHERE p.post_type = '$POST_TYPE'
GROUP BY pm.meta_key
ORDER BY count DESC;
" > "$OUT_DIR/meta_keys.tsv"

ok "meta_keys.tsv"

# ------------------------------------------
# 5. TSV → CSV 変換
# NotebookLMはCSV対応なので納品用に変換する。
# ------------------------------------------

log "TSVをCSVへ変換"

python3 - "$OUT_DIR" <<'PY'
import csv
import sys
from pathlib import Path

out_dir = Path(sys.argv[1])

for tsv_path in out_dir.glob("*.tsv"):
    csv_path = tsv_path.with_suffix(".csv")

    with tsv_path.open("r", encoding="utf-8", newline="") as fin, \
         csv_path.open("w", encoding="utf-8", newline="") as fout:
        reader = csv.reader(fin, delimiter="\t")
        writer = csv.writer(
            fout,
            delimiter=",",
            quotechar='"',
            quoting=csv.QUOTE_MINIMAL,
        )

        for row in reader:
            writer.writerow(row)

    print(f"[OK] {tsv_path.name} -> {csv_path.name}")
PY

# ------------------------------------------
# 6. 出力確認
# ------------------------------------------

log "出力ファイル一覧"
ls -lh "$OUT_DIR"

FLAT_LINES="$(wc -l < "$OUT_DIR/lg_job_flat_for_notebooklm.tsv")"
HIDDEN_LINES="$(wc -l < "$OUT_DIR/hidden_company_jobs.tsv")"

ok "主力TSV行数: $FLAT_LINES 行（ヘッダー込み）"
ok "非公開求人TSV行数: $HIDDEN_LINES 行（ヘッダー込み）"
ok "完了: $OUT_DIR"

echo
echo "Windowsで開く場合:"
echo "  explorer.exe \"$OUT_DIR\""