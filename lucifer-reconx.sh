#!/usr/bin/env bash
# ---------------------------------------------------------
# Lucifer-ReconX  —  All-in-One Bug Bounty Automation Tool
# Author : Lucifer
# Version: 1.0
# ---------------------------------------------------------
# Description:
# This tool automates recon, scanning & analysis phases
# using industry-standard tools (subfinder, amass, httpx,
# gau, waybackurls, hakrawler, nuclei, dalfox, sqlmap, ffuf)
# ---------------------------------------------------------

# -------------[ Colors ]-------------
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"

# -------------[ Banner ]-------------
banner() {
  clear
  echo -e "${MAGENTA}"
  echo "╔═══════════════════════════════════════════════╗"
  echo "║          L U C I F E R  -  R E C O N X        ║"
  echo "╠═══════════════════════════════════════════════╣"
  echo "║   ⚡ Automated Bug Bounty Recon Toolkit ⚡     ║"
  echo "║          Created by: ${RED}Lucifer${MAGENTA}              ║"
  echo "╚═══════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

# -------------[ Help Section ]-------------
show_help() {
  echo -e "${CYAN}Usage:${RESET}"
  echo "  sudo ./lucifer-reconx.sh <target.com> [wordlist]"
  echo ""
  echo -e "${CYAN}Options:${RESET}"
  echo "  -h, --help        Show this help message"
  echo "  -u, --update      Update Lucifer-ReconX to latest version"
  echo ""
  echo -e "${CYAN}Example:${RESET}"
  echo "  sudo ./lucifer-reconx.sh example.com"
  echo "  sudo ./lucifer-reconx.sh example.com /usr/share/wordlists/dirb/common.txt"
  echo ""
  echo -e "${YELLOW}Note:${RESET} Run only on authorized bug bounty targets!"
  exit 0
}

# -------------[ Update Function ]-------------
update_tool() {
  echo -e "${GREEN}[*] Updating Lucifer-ReconX...${RESET}"
  git pull origin main
  chmod +x lucifer-reconx.sh
  echo -e "${GREEN}[*] Updated successfully.${RESET}"
  exit 0
}

# -------------[ Root Check ]-------------
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run as root (sudo).${RESET}"
  exit 1
fi

# -------------[ Args Check ]-------------
if [[ "$1" == "-h" || "$1" == "--help" ]]; then show_help; fi
if [[ "$1" == "-u" || "$1" == "--update" ]]; then update_tool; fi
if [ $# -lt 1 ]; then show_help; fi

banner

TARGET="$1"
WORDLIST="${2:-/usr/share/seclists/Discovery/Web-Content/raft-small-words.txt}"
TARGET_CLEAN=$(echo "$TARGET" | sed 's#https\?://##;s#/##')
WORKDIR="$PWD/workspace/$TARGET_CLEAN"
OUT="$WORKDIR/output"
LOG="$WORKDIR/log.txt"
mkdir -p "$OUT"

echo -e "${GREEN}[+] Starting scan for:${RESET} $TARGET"
echo "Logs: $LOG"
sleep 1

# -------------[ Dependency Check ]-------------
TOOLS=(subfinder amass httpx gau waybackurls hakrawler nuclei dalfox sqlmap ffuf zip)
for t in "${TOOLS[@]}"; do
  if ! command -v $t &>/dev/null; then
    echo -e "${RED}[!] Missing tool:$RESET $t"
    echo "    Install it via apt/go install or run setup script."
    MISSING=true
  fi
done
if [ "$MISSING" = true ]; then
  echo -e "${RED}Install missing tools before running again.${RESET}"
  exit 1
fi

# -------------[ Recon Start ]-------------
echo -e "${YELLOW}[*] Subdomain enumeration...${RESET}"
subfinder -d "$TARGET_CLEAN" -silent -o "$OUT/subfinder.txt"
amass enum -d "$TARGET_CLEAN" -passive -o "$OUT/amass.txt"
cat "$OUT/"*.txt | sort -u > "$OUT/subs.txt"

echo -e "${YELLOW}[*] Checking live hosts...${RESET}"
httpx -l "$OUT/subs.txt" -silent -o "$OUT/live.txt"

echo -e "${YELLOW}[*] Collecting URLs (gau + waybackurls)...${RESET}"
cat "$OUT/live.txt" | gau > "$OUT/gau.txt"
cat "$OUT/live.txt" | waybackurls >> "$OUT/gau.txt"
sort -u "$OUT/gau.txt" > "$OUT/urls.txt"

echo -e "${YELLOW}[*] Crawling URLs with hakrawler...${RESET}"
> "$OUT/crawled.txt"
for url in $(cat "$OUT/live.txt"); do
  hakrawler -url "https://$url" -depth 2 -plain >> "$OUT/crawled.txt"
done

# Parameterized URLs
grep -E "\?.+=" "$OUT/crawled.txt" > "$OUT/params.txt"

# Nuclei scanning
echo -e "${YELLOW}[*] Running nuclei (safe mode)...${RESET}"
nuclei -l "$OUT/live.txt" -severity low,medium -o "$OUT/nuclei.txt"

# XSS Check
echo -e "${YELLOW}[*] Running dalfox (XSS check)...${RESET}"
cat "$OUT/params.txt" | dalfox pipe --skip-bav -o "$OUT/dalfox.txt"

# SQLi check
echo -e "${YELLOW}[*] Running SQLmap safe mode...${RESET}"
grep "id=" "$OUT/params.txt" | head -n 5 | while read -r u; do
  sqlmap -u "$u" --batch --risk=1 --level=1 >> "$OUT/sqlmap.txt"
done

# Fuzzing
echo -e "${YELLOW}[*] Directory fuzzing (ffuf)...${RESET}"
ffuf -w "$WORDLIST" -u "https://$(head -n1 $OUT/live.txt)/FUZZ" -mc 200,403 -t 30 -o "$OUT/ffuf.json"

# Packaging results
zip -r "$WORKDIR/results.zip" "$OUT" >/dev/null

echo -e "${GREEN}[*] Scan complete!${RESET}"
echo -e "📁 Results saved in: ${BLUE}$WORKDIR/results.zip${RESET}"
echo -e "👾 Tool by: ${RED}Lucifer${RESET}"
