#!/bin/bash
# Setup script to install tools for tissue.sh

set -e

echo "[*] Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "[*] Installing basic dependencies..."
sudo apt install -y git curl wget unzip python3 python3-pip build-essential nmap

echo "[*] Installing Go..."
if ! command -v go &>/dev/null; then
  wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
  sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
  rm go1.21.5.linux-amd64.tar.gz
  echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
  echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.zshrc
  export PATH=$PATH:/usr/local/go/bin
fi

echo "[*] Setting up Go environment..."
mkdir -p ~/go/bin
if ! grep -q "export GOPATH=" ~/.bashrc; then
  echo "export GOPATH=\$HOME/go" >> ~/.bashrc
  echo "export PATH=\$PATH:\$GOPATH/bin" >> ~/.bashrc
  echo "export GOPATH=\$HOME/go" >> ~/.zshrc
  echo "export PATH=\$PATH:\$GOPATH/bin" >> ~/.zshrc
fi
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

echo "[*] Installing tools via go install..."
go install github.com/owasp-amass/amass/v3/...@latest
go install github.com/tomnomnom/assetfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
go install github.com/hahwul/dalfox/v2@latest
go install github.com/ffuf/ffuf@latest

echo "[*] Installing Python dependencies..."
pip3 install --upgrade pip

echo "[*] Installation complete!"
echo "Run: source ~/.bashrc or source ~/.zshrc"
echo "Tools installed: amass, assetfinder, httpx, katana, gau, nuclei, dalfox, ffuf, nmap"
