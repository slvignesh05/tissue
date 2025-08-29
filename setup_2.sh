#!/bin/bash
# setup_2.sh - Install recon and scanning tools (fixed)

set -e

echo "[*] Installing dependencies..."
sudo apt update && sudo apt install -y golang-go git wget python3 python3-pip dirb

TOOLS_DIR="$HOME/recon_tools"
mkdir -p $TOOLS_DIR && cd $TOOLS_DIR

install_tool() {
    TOOL=$1
    CMD=$2
    BIN=$3
    echo "[*] Installing $TOOL..."
    go install $CMD
    sudo ln -sf ~/go/bin/$BIN /usr/local/bin/$BIN
}

install_tool "GoBuster" "github.com/OJ/gobuster/v3@latest" "gobuster"
install_tool "GoSpider" "github.com/jaeles-project/gospider@latest" "gospider"
install_tool "Waybackurls" "github.com/tomnomnom/waybackurls@latest" "waybackurls"
install_tool "CRLFuzz" "github.com/dwisiswant0/crlfuzz/cmd/crlfuzz@latest" "crlfuzz"
install_tool "Nuclei" "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" "nuclei"

echo "[+] All tools installed successfully!"
