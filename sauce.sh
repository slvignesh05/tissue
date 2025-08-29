#!/bin/bash
# sauce.sh - Automate recon & scanning on 100 URLs

set -e

URLS_FILE="urls.txt"  # Put 100 target URLs here
OUTPUT_DIR="scan_results"
mkdir -p $OUTPUT_DIR

if [[ ! -f $URLS_FILE ]]; then
    echo "[-] Please create a file named urls.txt with your 100 target URLs."
    exit 1
fi

echo "[*] Starting scans for URLs in $URLS_FILE"

while read -r url; do
    [[ -z "$url" ]] && continue
    domain=$(echo $url | sed 's|https\?://||' | cut -d/ -f1)
    echo "[*] Scanning: $url"

    mkdir -p "$OUTPUT_DIR/$domain"

    # GoBuster (directory brute-force)
    gobuster dir -u "$url" -w /usr/share/wordlists/dirb/common.txt -o "$OUTPUT_DIR/$domain/gobuster.txt"

    # GoSpider (crawl links)
    gospider -s "$url" -o "$OUTPUT_DIR/$domain/gospider.txt"

    # KiteRunner (API endpoint scan)
    kr scan $url -w ~/go/bin/routes-large.kite -o "$OUTPUT_DIR/$domain/kiterunner.txt"

    # Waybackurls (URLs from archive.org)
    echo "$url" | waybackurls > "$OUTPUT_DIR/$domain/waybackurls.txt"

    # CRLFuzz
    crlfuzz -u "$url" -o "$OUTPUT_DIR/$domain/crlfuzz.txt"

    # Nuclei (Vulnerability templates)
    nuclei -u "$url" -o "$OUTPUT_DIR/$domain/nuclei.txt"

    echo "[+] Completed: $url"
done < "$URLS_FILE"

echo "[+] All scans saved in $OUTPUT_DIR"
