#!/bin/bash
set -euo pipefail

OUT_FILE="lib/config/env.g.dart"
echo "// GENERATED FILE. DO NOT EDIT." > "$OUT_FILE"
echo "class Env {" >> "$OUT_FILE"
while IFS='=' read -r key value; do
  [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
  key_clean=$(echo "$key" | tr -d ' ')
  value_clean=$(echo "$value" | sed 's/^\"//;s/\"$//')
  echo "  static const String $key_clean = \"$value_clean\";" >> "$OUT_FILE"
done < <(grep -v '^#' env.sh | grep '=')
echo "}" >> "$OUT_FILE"
echo "[DART ENV] Generated $OUT_FILE with env.sh variables." 