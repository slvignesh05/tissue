#!/usr/bin/env bash
set -euo pipefail

# tissue.sh - Full Web Recon & Vulnerability Scanner
# Usage: ./tissue.sh -f urls.txt
# Requirements: amass, assetfinder, httpx, gau, katana, ffuf, nuclei, dalfox, nmap, waybackurls

INPUT=""
OUTDIR="tissue_output"
THREADS=50

# Parse arguments
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
log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"; }

# ----------------------------
# 1. Validate Input URLs
# ----------------------------
log "[*] Cleaning URL list..."
URLS_CLEAN="$OUTDIR/urls_clean.txt"
grep -Eo 'https?://[^ ]+' "$INPUT" | sort -u > "$URLS_CLEAN"

# ----------------------------
# 2. Subdomain Enumeration
# ----------------------------
log "[*] Enumerating subdomains..."
SUBDOMS="$OUTDIR/subdomains.txt"
if command -v amass >/dev/null; then
  amass enum -passive -df "$URLS_CLEAN" -o "$SUBDOMS" || true
fi
if command -v assetfinder >/dev/null; then
  assetfinder --subs-only $(awk -F/ '{print $3}' "$URLS_CLEAN") >> "$SUBDOMS" || true
fi
sort -u "$SUBDOMS" -o "$SUBDOMS"

# ----------------------------
# 3. Live Host Checking
# ----------------------------
log "[*] Checking live hosts..."
LIVE="$OUTDIR/live_hosts.txt"
cat "$URLS_CLEAN" "$SUBDOMS" | sort -u | httpx -silent -threads "$THREADS" > "$LIVE"

# ----------------------------
# 4. Crawl URLs
# ----------------------------
log "[*] Crawling endpoints..."
CRAWLED="$OUTDIR/crawled_urls.txt"
if command -v katana >/dev/null; then
  katana -list "$LIVE" -silent -o "$CRAWLED" || true
fi
if command -v gau >/dev/null; then
  cat "$LIVE" | gau >> "$CRAWLED" || true
fi
sort -u "$CRAWLED" -o "$CRAWLED"

# ----------------------------
# 5. Parameter Discovery
# ----------------------------
log "[*] Finding parameters..."
PARAMS="$OUTDIR/parameters.txt"
grep "?" "$CRAWLED" | sort -u > "$PARAMS"

# ----------------------------
# 6. Vulnerability Scans
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

# SQLi / XSS Testing
if command -v dalfox >/dev/null; then
  log "[*] Testing XSS with Dalfox..."
  dalfox file "$PARAMS" -o "$VULNS_DIR/xss.txt" --silence || true
fi

# Path Traversal Fuzz
if command -v ffuf >/dev/null; then
  log "[*] Testing Path Traversal..."
  ffuf -w /usr/share/seclists/Fuzzing/LFI/LFI-gracefulsecurity-linux.txt \
    -u FUZZ -mc all -o "$VULNS_DIR/path_traversal.json" || true
fi

# Cache Deception Check
log "[*] Checking Cache Deception..."
CACHE_DECEPTION="$VULNS_DIR/cache_deception.txt"
for url in $(cat "$LIVE"); do
  curl -s -o /dev/null -w "$url - %{http_code}\n" "$url/random.css" >> "$CACHE_DECEPTION" &
done
wait

# HTTP Request Smuggling
log "[*] Checking HTTP Request Smuggling..."
SMUGGLING="$VULNS_DIR/http_smuggling.txt"
for url in $(cat "$LIVE"); do
  curl -s -i -H "Transfer-Encoding: chunked" -H "Content-Length: 3" "$url" \
    | grep -qi "HTTP/1.1" && echo "$url" >> "$SMUGGLING" &
done
wait

# ----------------------------
# 7. Nmap Scan for Misconfigured Ports
# ----------------------------
if command -v nmap >/dev/null; then
  log "[*] Running Nmap scan for open/misconfigured ports..."
  NMAP_RESULTS="$VULNS_DIR/nmap_results"
  mkdir -p "$NMAP_RESULTS"
  for url in $(cat "$LIVE"); do
    host=$(echo "$url" | awk -F/ '{print $3}')
    log "    Scanning host: $host"
    nmap -Pn -T4 --top-ports 1000 -sV -sC "$host" -oN "$NMAP_RESULTS/${host}_nmap.txt" &
  done
  wait
fi

# ----------------------------
# 8. Output Summary
# ----------------------------
log "[+] Scan complete. Results saved in: $OUTDIR"
log "    - Live Hosts: $LIVE"
log "    - Subdomains: $SUBDOMS"
log "    - Crawled URLs: $CRAWLED"
log "    - Parameters: $PARAMS"
log "    - Vulnerabilities: $VULNS_DIR"
