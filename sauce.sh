#!/bin/bash

# sauce.sh - Simple URL scanner
# Usage: ./sauce.sh -f urls.txt

set -euo pipefail

INPUT_FILE=""
OUTPUT_DIR="scan_results"
WORDLIST="/usr/share/wordlists/dirb/common.txt"

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

usage() {
    echo "Usage: $0 -f <file_with_urls>"
    exit 1
}

while getopts ":f:" opt; do
    case ${opt} in
        f ) INPUT_FILE=$OPTARG ;;
        * ) usage ;;
    esac
done

if [[ -z "$INPUT_FILE" ]]; then
    usage
fi

mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}[*] Starting scans for URLs in $INPUT_FILE${RESET}"

while read -r URL; do
    [[ -z "$URL" ]] && continue
    echo -e "${YELLOW}[*] Scanning: $URL${RESET}"
    URL_DIR="$OUTPUT_DIR/$URL"
    mkdir -p "$URL_DIR"

    # 1. Basic HTTP check
    echo "[*] Running httpx..." 
    httpx -silent -status-code -title -tech-detect -no-color -o "$URL_DIR/httpx.txt" -u "$URL" || true

    # 2. Directory bruteforce (ignore wildcard issues)
    echo "[*] Running gobuster..."
    gobuster dir -u "http://$URL" -w "$WORDLIST" -q -o "$URL_DIR/gobuster.txt" \
        -k -b 301,302,403,404 || true

    # 3. Crawl site (ignore failures)
    echo "[*] Running gosub..."
    gosub -u "http://$URL" > "$URL_DIR/gosub.txt" 2>/dev/null || true

    # 4. CVE Scans
    echo "[*] Running nuclei CVE scan..."
    nuclei -u "$URL" -tags cve -o "$URL_DIR/nuclei.txt" -silent || true

    echo -e "${GREEN}[+] Completed: $URL${RESET}\n"
done < "$INPUT_FILE"

echo -e "${GREEN}[+] All scans completed. Results saved in $OUTPUT_DIR${RESET}"
