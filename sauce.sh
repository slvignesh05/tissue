#!/bin/bash
# sauce.sh - Automate recon & scanning on URLs from a file
# Usage: ./sauce.sh -f urls.txt

set -euo pipefail

usage() {
    echo "Usage: $0 -f <urls.txt>"
    exit 1
}

check_tools() {
    tools=(gobuster gospider kr waybackurls crlfuzz nuclei wget)
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            echo "[-] $tool not found. Please run setup_2.sh first."
            exit 1
        fi
    done
}

get_wordlist() {
    WORDLIST="/usr/share/wordlists/dirb/common.txt"
    if [[ ! -f "$WORDLIST" ]]; then
        echo "[*] Wordlist not found. Downloading..."
        sudo mkdir -p /usr/share/wordlists/dirb
        sudo wget -qO "$WORDLIST" https://raw.githubusercontent.com/v0re/dirb/master/wordlists/common.txt
    fi
    echo "$WORDLIST"
}

# --------- PARSE ARGS ---------
URLS_FILE=""
while getopts "f:" opt; do
    case ${opt} in
        f) URLS_FILE=$OPTARG ;;
        *) usage ;;
    esac
done

if [[ -z "$URLS_FILE" ]]; then
    usage
fi

if [[ ! -f "$URLS_FILE" ]]; then
    echo "[-] File $URLS_FILE not found!"
    exit 1
fi

# --------- MAIN ---------
OUTPUT_DIR="scan_results"
mkdir -p "$OUTPUT_DIR"

check_tools
WORDLIST=$(get_wordlist)

echo "[*] Starting scans for URLs in $URLS_FILE"

while read -r url; do
    [[ -z "$url" ]] && continue
    domain=$(echo "$url" | sed 's|https\?://||' | cut -d/ -f1)
    echo "[*] Scanning: $url"
    mkdir -p "$OUTPUT_DIR/$domain"

    # GoBuster
    gobuster dir -u "$url" -w "$WORDLIST" \
        -o "$OUTPUT_DIR/$domain/gobuster.txt" || echo "[!] Gobuster failed for $url"

    # GoSpider
    gospider -s "$url" -o "$OUTPUT_DIR/$domain/gospider.txt" || echo "[!] GoSpider failed for $url"

    # KiteRunner
    kr scan "$url" -w ~/go/bin/routes-large.kite \
        -o "$OUTPUT_DIR/$domain/kiterunner.txt" || echo "[!] KiteRunner failed for $url"

    # Waybackurls
    echo "$url" | waybackurls > "$OUTPUT_DIR/$domain/waybackurls.txt" || echo "[!] Waybackurls failed for $url"

    # CRLFuzz
    crlfuzz -u "$url" -o "$OUTPUT_DIR/$domain/crlfuzz.txt" || echo "[!] CRLFuzz failed for $url"

    # Nuclei
    nuclei -u "$url" -o "$OUTPUT_DIR/$domain/nuclei.txt" || echo "[!] Nuclei failed for $url"

    echo "[+] Completed: $url"
done < "$URLS_FILE"

echo "[+] All scans completed. Results saved in $OUTPUT_DIR"
