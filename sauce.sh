#!/bin/bash

# sauce.sh - Recon & vuln scanning automation
# Tools: httpx, gobuster, gospider, waybackurls, crlfuzz, nuclei

WORDLIST="common.txt"
RESULTS_DIR="scan_results"
URLS_FILE="urls.txt"

# Download wordlist if missing
if [[ ! -f $WORDLIST ]]; then
    echo "[*] Downloading wordlist..."
    curl -s -o $WORDLIST https://raw.githubusercontent.com/v0re/dirb/master/wordlists/common.txt
fi

mkdir -p "$RESULTS_DIR"

if [[ ! -f $URLS_FILE ]]; then
    echo "[!] No urls.txt found! Put your URLs inside urls.txt"
    exit 1
fi

while read -r URL; do
    [[ -z "$URL" ]] && continue
    DOMAIN=$(echo $URL | sed 's~http[s]*://~~' | sed 's~/.*~~')

    TARGET_DIR="$RESULTS_DIR/$DOMAIN"
    mkdir -p "$TARGET_DIR"

    echo -e "\n[*] Checking $URL with httpx..."
    ACTIVE=$(echo $URL | httpx -silent -mc 200)
    if [[ -z "$ACTIVE" ]]; then
        echo "[!] No active 200 URL found for $URL"
        continue
    fi
    echo "[+] $URL is live!"

    echo "[*] Starting GoBuster..."
    gobuster dir -u "$URL" -w "$WORDLIST" -t 10 -q -o "$TARGET_DIR/gobuster.txt" || echo "[!] Gobuster failed"

    echo "[*] Starting GoSpider..."
    gospider -s "$URL" -o "$TARGET_DIR/gospider" --quiet || echo "[!] GoSpider failed"

    echo "[*] Running Waybackurls..."
    echo "$URL" | waybackurls > "$TARGET_DIR/waybackurls.txt"

    echo "[*] Running CRLFuzz..."
    crlfuzz -u "$URL" -o "$TARGET_DIR/crlfuzz.txt" || echo "[!] CRLFuzz failed"

    echo "[*] Running Nuclei..."
    nuclei -u "$URL" -o "$TARGET_DIR/nuclei.txt"

    echo "[+] Completed: $URL"
done < "$URLS_FILE"

echo -e "\n[+] All scans completed! Results saved in $RESULTS_DIR/"
