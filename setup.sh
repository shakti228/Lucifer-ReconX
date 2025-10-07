#!/usr/bin/env bash
# Lucifer-ReconX setup script

echo "[*] Installing dependencies..."
sudo apt update -y
sudo apt install -y git curl jq zip python3-pip

echo "[*] Installing Go tools..."
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/OWASP/Amass/v3/...@master
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/lc/gau/v2/cmd/gau@latest
go install -v github.com/tomnomnom/waybackurls@latest
go install -v github.com/hakluke/hakrawler@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/hahwul/dalfox/v2@latest
go install -v github.com/ffuf/ffuf@latest

echo "[*] All tools installed successfully!"
chmod +x lucifer-reconx.sh
