#!/usr/bin/env bash
set -euo pipefail

# tissue.sh - Web Recon & Vulnerability Scanner (No Subdomain Enumeration)
# Usage: ./tissue.sh -f urls.txt [-o output_dir]
# Requirements: httpx, gau, katana, ffuf, nuclei, dalfox, nmap

INPUT=""
OUTDIR="tissue_output"
THREADS=50
TIMEOUT=10s
FFUF_WORDLIST="/usr/share/seclists/Fuzzing/LFI/LFI-gracefulsecurity-linux.txt"

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"; }

# ----------------------------
# Parse arguments
# ----------------------------
while getopts "f:o:" opt; do
  case $opt in
    f) INPUT=$OPTARG ;;
    o) OUTDIR=$OPTARG ;;
    *) echo "Usage: $0 -f urls.txt [-o output_dir]" && exit 1 ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "[-] Input file required!"
  echo "Usage: $0 -f urls.txt [-o output_dir]"
  exit 1
fi

mkdir -p "$OUTDIR"

# ----------------------------
# 1. Clean input URLs
# ----------------------------
log "[*] Cleaning input list..."
URLS_CLEAN="$OUTDIR/urls_clean.txt"
awk '{print $1}' "$INPUT" | sort -u > "$URLS_CLEAN"

# ----------------------------
# 2. Live Host Checking
# ----------------------------
log "[*] Checking live hosts..."
LIVE="$OUTDIR/live_hosts.txt"
httpx -l "$URLS_CLEAN" -silent -threads "$THREADS" -timeout 10 -retries 1 > "$LIVE"

# ----------------------------
# 3. Crawl URLs
# ----------------------------
log "[*] Crawling endpoints..."
CRAWLED="$OUTDIR/crawled_urls.txt"
> "$CRAWLED"

if command -v katana >/dev/null; then
    xargs -a "$LIVE" -n1 -P"$THREADS" -I{} timeout $TIMEOUT katana -u {} -silent -o /tmp/katana_out.txt || true
    cat /tmp/katana_out.txt >> "$CRAWLED"
fi

if command -v gau >/dev/null; then
    xargs -a "$LIVE" -n1 -P"$THREADS" -I{} timeout $TIMEOUT gau {} 2>/dev/null >> "$CRAWLED" || true
fi

sort -u "$CRAWLED" -o "$CRAWLED"

# ----------------------------
# 4. Parameter Discovery
# ----------------------------
log "[*] Finding parameters..."
PARAMS="$OUTDIR/parameters.txt"
grep "?" "$CRAWLED" | sort -u > "$PARAMS"

# ----------------------------
# 5. Vulnerability Scans
# ----------------------------
VULNS_DIR="$OUTDIR/vulns"
mkdir -p "$VULNS_DIR"

# Nuclei Scan
if command -v nuclei >/dev/null; then
    log "[*] Running Nuclei templates..."
    nuclei -l "$LIVE" -t cves/ -t vulnerabilities/ \
        -o "$VULNS_DIR/nuclei_findings.txt" \
        -severity low,medium,high,critical || true
fi

# XSS Testing with Dalfox
if command -v dalfox >/dev/null && [[ -s "$PARAMS" ]]; then
    log "[*] Testing XSS with Dalfox..."
    dalfox file "$PARAMS" -o "$VULNS_DIR/xss.txt" --silence || true
fi

# Path Traversal Fuzz
if [[ -f "$FFUF_WORDLIST" ]]; then
    log "[*] Testing Path Traversal..."
    ffuf -w "$FFUF_WORDLIST" -u FUZZ -mc all -o "$VULNS_DIR/path_traversal.json" || true
else
    log "[-] FFUF wordlist not found, skipping Path Traversal"
fi

# Cache Deception
log "[*] Checking Cache Deception..."
CACHE_DECEPTION="$VULNS_DIR/cache_deception.txt"
while read -r url; do
    timeout $TIMEOUT curl -s -o /dev/null -w "$url - %{http_code}\n" "$url/random.css" >> "$CACHE_DECEPTION" &
done < "$LIVE"
wait

# HTTP Request Smuggling
log "[*] Checking HTTP Request Smuggling..."
SMUGGLING="$VULNS_DIR/http_smuggling.txt"
while read -r url; do
    timeout $TIMEOUT curl -s -i -H "Transfer-Encoding: chunked" -H "Content-Length: 3" "$url" \
        | grep -qi "HTTP/1.1" && echo "$url" >> "$SMUGGLING" &
done < "$LIVE"
wait

# ----------------------------
# 6. Nmap Scan (limited parallelism)
# ----------------------------
if command -v nmap >/dev/null; then
    log "[*] Running Nmap scan..."
    NMAP_RESULTS="$VULNS_DIR/nmap_results"
    mkdir -p "$NMAP_RESULTS"

    xargs -a "$LIVE" -P10 -I{} bash -c '
        host=$(echo {} | awk -F/ "{print \$3}")
        if [[ -n "$host" ]]; then
            log "[*] Scanning host: $host"
            nmap -Pn -T4 --top-ports 1000 -sV -sC "$host" -oN "'"$NMAP_RESULTS"'/${host}_nmap.txt"
        fi
    '
fi

# ----------------------------
# 7. Summary
# ----------------------------
log "[+] Scan complete. Results saved in: $OUTDIR"
log "    - Live Hosts: $LIVE"
log "    - Crawled URLs: $CRAWLED"
log "    - Parameters: $PARAMS"
log "    - Vulnerabilities: $VULNS_DIR"
