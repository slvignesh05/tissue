#!/bin/bash
# sauce.sh: Scan URLs for vulnerabilities with multiple tools
# Saves ONLY findings in a single JSON file (scan_results/vulnerabilities.json)

INPUT_FILE=""
OUTPUT_FILE="scan_results/vulnerabilities.json"
WORDLIST="/usr/share/wordlists/dirb/common.txt" # Change if needed

while getopts "f:" opt; do
  case ${opt} in
    f ) INPUT_FILE=$OPTARG ;;
    * ) echo "Usage: $0 -f <urls.txt>"; exit 1 ;;
  esac
done

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
  echo "[-] Input file missing or not found!"
  exit 1
fi

mkdir -p scan_results
> "$OUTPUT_FILE"
echo "[" > "$OUTPUT_FILE"

while read -r url; do
  [[ -z "$url" ]] && continue
  echo "[*] Scanning: $url"

  active_url=$(echo "$url" | httpx -silent -mc 200)
  if [[ -z "$active_url" ]]; then
    echo "[-] Skipping $url (not reachable)"
    continue
  fi

  json_entry="{\"url\":\"$url\""
  findings=()

  # === NUCLEI SCAN ===
  nuclei_out=$(echo "$url" | nuclei -silent -tags cve -json 2>/dev/null)
  if [[ -n "$nuclei_out" ]]; then
    findings+=("\"nuclei\":[$(echo "$nuclei_out" | jq -c -s '.[]')]")
  fi

  # === GOBUSTER ===
  gobuster_out=$(gobuster dir -u "$url" -w "$WORDLIST" -q -o /dev/stdout 2>/dev/null)
  if [[ -n "$gobuster_out" ]]; then
    findings+=("\"gobuster\":[\"$(echo "$gobuster_out" | sed ':a;N;$!ba;s/\n/","/g')\"]")
  fi

  # === GOSPIDER ===
  gospider_out=$(gospider -s "$url" -d 1 -q --json 2>/dev/null)
  if [[ -n "$gospider_out" ]]; then
    findings+=("\"gospider\":[\"$(echo "$gospider_out" | jq -r '.output' | sed ':a;N;$!ba;s/\n/","/g')\"]")
  fi

  # === CRLFUZZ ===
  crlfuzz_out=$(crlfuzz -u "$url" -silent 2>/dev/null)
  if [[ -n "$crlfuzz_out" ]]; then
    findings+=("\"crlfuzz\":[\"$(echo "$crlfuzz_out" | sed ':a;N;$!ba;s/\n/","/g')\"]")
  fi

  if [[ ${#findings[@]} -gt 0 ]]; then
    json_entry+=",${findings[*]}}"
    echo "$json_entry," >> "$OUTPUT_FILE"
    echo "[+] Findings logged for $url"
  else
    echo "[-] No issues found for $url"
  fi

done < "$INPUT_FILE"

sed -i '$ s/,$//' "$OUTPUT_FILE"
echo "]" >> "$OUTPUT_FILE"

echo "[+] All results saved in $OUTPUT_FILE"
