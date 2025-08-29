#!/bin/bash
# setup_2.sh - Install recon and scanning tools

set -e

echo "[*] Installing dependencies..."
sudo apt update && sudo apt install -y golang-go git wget python3 python3-pip

TOOLS_DIR="$HOME/recon_tools"
mkdir -p $TOOLS_DIR && cd $TOOLS_DIR

# Install GoBuster
echo "[*] Installing GoBuster..."
go install github.com/OJ/gobuster/v3@latest
ln -sf ~/go/bin/gobuster /usr/local/bin/gobuster

# Install GoSpider
echo "[*] Installing GoSpider..."
go install github.com/jaeles-project/gospider@latest
ln -sf ~/go/bin/gospider /usr/local/bin/gospider

# Install KiteRunner
echo "[*] Installing KiteRunner..."
go install github.com/assetnote/kiterunner@latest
ln -sf ~/go/bin/kr /usr/local/bin/kr

# Install Waybackurls
echo "[*] Installing Waybackurls..."
go install github.com/tomnomnom/waybackurls@latest
ln -sf ~/go/bin/waybackurls /usr/local/bin/waybackurls

# Install CRLFuzz
echo "[*] Installing CRLFuzz..."
go install github.com/dwisiswant0/crlfuzz/cmd/crlfuzz@latest
ln -sf ~/go/bin/crlfuzz /usr/local/bin/crlfuzz

# Install Nuclei
echo "[*] Installing Nuclei..."
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
ln -sf ~/go/bin/nuclei /usr/local/bin/nuclei

echo "[+] All tools installed successfully in $TOOLS_DIR"
