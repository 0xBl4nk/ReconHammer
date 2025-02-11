#!/usr/bin/env bash
#
# recon_workflow_improved.sh
#
# Simple Recon Workflow:
#   - Parameter for threads (--threads N)
#   - Parameter for Nmap vuln scripts (--vuln)
#   - Verbose parameter (--verbose) for subfinder, etc.
#   - Checks for required dependencies
#   - Uses CORScanner (cors_scan.py in ./CORScanner) and Dirsearch (dirsearch.py in ./dirsearch)
#   - Logs to a file
#   - Generates a final HTML report
#   - Groups ports for Nmap scans
#
# Usage:
#   ./recon_workflow_improved.sh <domain> [--threads <NUM>] [--vuln] [--verbose]
#
# Required Dependencies (must be installed and in PATH):
#   - subfinder
#   - subjack
#   - massdns
#   - aquatone
#   - masscan
#   - nmap
#   - xsltproc
#   - parallel
#   - jq
#   - python3
#
# Author/Credits: 0xBl4nk
#

set -e  # Stop on error
set -u  # Treat unset variables as errors

#####################################
# [0] Usage Function
#####################################
function usage() {
  echo "Usage:"
  echo "  $0 <domain> [--threads <NUM>] [--vuln] [--verbose]"
  echo
  echo "Options:"
  echo "  --threads <NUM> : Number of threads (default: 5)."
  echo "  --vuln          : Enable 'vuln' script for Nmap."
  echo "  --verbose       : Show detailed output for certain tools."
  echo
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

DOMAIN="$1"
shift

THREADS=5
VULN_SCAN=0
VERBOSE=0

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --threads)
      THREADS="$2"
      shift
      shift
      ;;
    --vuln)
      VULN_SCAN=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    *)
      echo "[ERROR] Unknown option: $key"
      usage
      ;;
  esac
done

# Simple domain validation
if ! [[ "$DOMAIN" =~ ^[A-Za-z0-9._-]+\.[A-Za-z]{2,}$ ]]; then
  echo "[ERROR] Invalid domain: $DOMAIN"
  exit 1
fi

#####################################
# [1] Dependency Checks
#####################################
REQUIRED_CMDS=(
  "subfinder"
  "subjack"
  "massdns"
  "aquatone"
  "masscan"
  "nmap"
  "parallel"
  "xsltproc"
  "jq"
)

if ! command -v python3 &> /dev/null; then
  echo "[ERROR] 'python3' not found."
  exit 1
fi

for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "[ERROR] Missing required tool: $cmd"
    exit 1
  fi
done

if [ ! -f "./CORScanner/cors_scan.py" ]; then
  echo "[ERROR] Missing ./CORScanner/cors_scan.py"
  exit 1
fi

if [ ! -f "./dirsearch/dirsearch.py" ]; then
  echo "[ERROR] Missing ./dirsearch/dirsearch.py"
  exit 1
fi

#####################################
# [2] Output & Logs
#####################################
OUTPUT_DIR="results_${DOMAIN}"
SUBDOMAINS_DIR="${OUTPUT_DIR}/subdomains"
SCAN_DIR="${OUTPUT_DIR}/scans"
AQUATONE_DIR="${OUTPUT_DIR}/aquatone"
MASSCAN_DIR="${OUTPUT_DIR}/masscan"
NMAP_DIR="${OUTPUT_DIR}/nmap"
DIRSEARCH_RESULT_DIR="${OUTPUT_DIR}/dirsearch"
LOG_DIR="${OUTPUT_DIR}/logs"

mkdir -p "${OUTPUT_DIR}" "${SUBDOMAINS_DIR}" "${SCAN_DIR}" \
         "${AQUATONE_DIR}" "${MASSCAN_DIR}" "${NMAP_DIR}" \
         "${DIRSEARCH_RESULT_DIR}" "${LOG_DIR}"

# Redirect stdout and stderr to log file
exec > >(tee -a "${LOG_DIR}/workflow.log") 2>&1

echo "============================================"
echo " Starting Recon for: ${DOMAIN}"
echo " Threads: ${THREADS}"
echo " Vuln Scan (Nmap): $( [ $VULN_SCAN -eq 1 ] && echo 'Enabled' || echo 'Disabled' )"
echo " Verbose: $( [ $VERBOSE -eq 1 ] && echo 'Enabled' || echo 'Disabled' )"
echo " Date/Time: $(date)"
echo "============================================"
echo

#####################################
# [3] Subdomain Enumeration (Subfinder only)
#####################################
echo "[1] Subdomain Enumeration..."

echo " > Running SUBFINDER..."
if [ $VERBOSE -eq 1 ]; then
  subfinder -d "${DOMAIN}" \
            -t "${THREADS}" \
            -v \
            -o "${SUBDOMAINS_DIR}/subfinder.txt" \
            2>> "${LOG_DIR}/subfinder_error.log"
else
  subfinder -d "${DOMAIN}" \
            -t "${THREADS}" \
            -o "${SUBDOMAINS_DIR}/subfinder.txt" \
            2>> "${LOG_DIR}/subfinder_error.log"
fi

# Filtra apenas domínios válidos
cat "${SUBDOMAINS_DIR}/subfinder.txt" \
  | grep -Eo '([a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,})' \
  | sort -u \
  > "${SUBDOMAINS_DIR}/final-subdomains.txt"

TOTAL_SUBS=$(wc -l < "${SUBDOMAINS_DIR}/final-subdomains.txt")
echo " > final-subdomains.txt created with ${TOTAL_SUBS} subdomains."
echo

#####################################
# [4] Subdomain Takeover (Subjack)
#####################################
echo "[2] Subdomain Takeover (Subjack)..."

if [ $VERBOSE -eq 1 ]; then
  SUBJACK_EXTRA_FLAGS="-v"
else
  SUBJACK_EXTRA_FLAGS=""
fi

set +e
subjack -w "${SUBDOMAINS_DIR}/final-subdomains.txt" \
        -t "${THREADS}" \
        -ssl \
        -o "${SCAN_DIR}/final-takeover.txt" \
        -v \
        2>> "${LOG_DIR}/subjack_error.log"
ret_subjack=$?
set -e

if [ $ret_subjack -ne 0 ]; then
  echo "[WARNING] Subjack returned code $ret_subjack."
fi

#####################################
# [5] CORS Scanner (CORScanner)
#####################################
echo "[3] CORS Scanner..."

CORS_CMD="python3 ./CORScanner/cors_scan.py"
CORS_VERBOSE=""

$CORS_CMD -i "${SUBDOMAINS_DIR}/final-subdomains.txt" \
          -t "${THREADS}" \
          $CORS_VERBOSE \
          -o "${SCAN_DIR}/final-cors.txt" \
          2>> "${LOG_DIR}/corscanner_error.log"

echo " > CORS check done. See final-cors.txt"
echo

#####################################
# [6] DNS Resolution (massdns)
#####################################
echo "[4] DNS Resolution with massdns..."

RESOLVERS_FILE="./resolvers.txt"
if [ ! -f "$RESOLVERS_FILE" ]; then
  echo "[ERROR] resolvers.txt not found."
  exit 1
fi

cp "${SUBDOMAINS_DIR}/final-subdomains.txt" "${SCAN_DIR}/massdns_input.txt"

massdns -r "$RESOLVERS_FILE" \
        -t A \
        -o S \
        -w "${SCAN_DIR}/massdns_output.txt" \
        "${SCAN_DIR}/massdns_input.txt" \
        2>> "${LOG_DIR}/massdns_error.log"

grep " A " "${SCAN_DIR}/massdns_output.txt" \
  | awk '{print $3}' \
  | sort -u \
  > "${SCAN_DIR}/combined_ips.txt"

cp "${SCAN_DIR}/combined_ips.txt" "${SCAN_DIR}/final-ips.txt"

TOTAL_IPS=$(wc -l < "${SCAN_DIR}/final-ips.txt")
echo " > final-ips.txt created with ${TOTAL_IPS} IPs."
echo

#####################################
# [7] Aquatone
#####################################
echo "[5] Aquatone Screenshots..."

cat "${SUBDOMAINS_DIR}/final-subdomains.txt" \
  | aquatone -out "${AQUATONE_DIR}" -threads "${THREADS}" \
  2>> "${LOG_DIR}/aquatone_error.log"

echo " > Aquatone done. See ${AQUATONE_DIR}"
echo

#####################################
# [8] Dirsearch using Parallel
#####################################
echo "[6] Dirsearch using Parallel..."

WORDLIST="./wordlist.txt"
if [ ! -f "$WORDLIST" ]; then
  echo "[ERROR] Wordlist not found at: $WORDLIST"
  exit 1
fi

# Use the dirsearch script (ensure it is executable)
DIRSEARCH_CMD="./dirsearch/dirsearch.py"

dirsearch_func() {
  local sub="$1"
  echo " > Running dirsearch on ${sub} (http)..."
  $DIRSEARCH_CMD -u "http://${sub}" \
      -e "php,asp,aspx,jsp,js,html,zip,txt" \
      -w "$WORDLIST" \
      -t "${THREADS}" \
      -o "${DIRSEARCH_RESULT_DIR}/${sub}_http.txt" \
      > /dev/null 2>&1

  echo " > Running dirsearch on ${sub} (https)..."
  $DIRSEARCH_CMD -u "https://${sub}" \
      -e "php,asp,aspx,jsp,js,html,zip,txt" \
      -w "$WORDLIST" \
      -t "${THREADS}" \
      -o "${DIRSEARCH_RESULT_DIR}/${sub}_https.txt" \
      > /dev/null 2>&1
}

export -f dirsearch_func
export DIRSEARCH_CMD WORDLIST THREADS DIRSEARCH_RESULT_DIR

cat "${SUBDOMAINS_DIR}/final-subdomains.txt" | parallel -j "${THREADS}" dirsearch_func {}

echo " > Dirsearch finished."
echo

#####################################
# [9] Masscan
#####################################
echo "[7] Masscan on all IPs..."

sudo masscan -iL "${SCAN_DIR}/final-ips.txt" \
             --ports 1-65535 \
             --rate 10000 \
             -oJ "${MASSCAN_DIR}/masscan_output.json" \
             2>> "${LOG_DIR}/masscan_error.log"

# Usando jq para extrair corretamente o IP e a(s) porta(s)
cat "${MASSCAN_DIR}/masscan_output.json" | \
  jq -r '.[] | .ip as $ip | .ports[]? | select(.port != null) | "\($ip):\(.port)"' \
  > "${MASSCAN_DIR}/open_ports.txt"

cp "${MASSCAN_DIR}/masscan_output.json" "${MASSCAN_DIR}/final-masscan.html"

echo " > Masscan done. Check open_ports.txt"
echo

#####################################
# [10] Nmap (Grouped Ports)
#####################################
echo "[8] Nmap scans..."

declare -A IP_PORTS

while read -r line; do
  IP=$(echo "$line" | cut -d ':' -f1)
  PORT=$(echo "$line" | cut -d ':' -f2)
  IP_PORTS["$IP"]+="$PORT,"
done < "${MASSCAN_DIR}/open_ports.txt"

NMAP_FLAGS="-sV -sC"
if [ $VULN_SCAN -eq 1 ]; then
  NMAP_FLAGS="$NMAP_FLAGS --script=vuln"
fi

for ip in "${!IP_PORTS[@]}"; do
  ports="${IP_PORTS[$ip]}"
  ports="${ports%,}"
  echo "   - Nmap for IP: $ip / Ports: $ports"

  nmap $NMAP_FLAGS -p "$ports" "$ip" \
       -oA "${NMAP_DIR}/${ip}" \
       > /dev/null 2>&1
done

for xmlfile in "${NMAP_DIR}"/*.xml; do
    [ -f "$xmlfile" ] || continue
    xsltproc "$xmlfile" -o "${xmlfile%.xml}.html" 2>> "${LOG_DIR}/nmap_xsltproc_error.log"
done

echo " > Nmap done."
echo

#####################################
# [11] HTML Report
#####################################
echo "[9] Generating final HTML report..."

REPORT_FILE="${OUTPUT_DIR}/report.html"

{
  echo "<html>"
  echo "  <head>"
  echo "    <meta charset=\"UTF-8\" />"
  echo "    <title>Recon Report - ${DOMAIN}</title>"
  echo "    <style> body { font-family: Arial, sans-serif; } </style>"
  echo "  </head>"
  echo "  <body>"
  echo "    <h1>Recon Report for ${DOMAIN}</h1>"
  echo "    <p>Generated on: $(date)</p>"
  echo "    <p>Threads: ${THREADS}</p>"
  echo "    <p>Nmap Vuln: $( [ $VULN_SCAN -eq 1 ] && echo 'Enabled' || echo 'Disabled' )</p>"
  echo "    <p>Verbose: $( [ $VERBOSE -eq 1 ] && echo 'Yes' || echo 'No' )</p>"

  echo "    <h2>1. Subdomains</h2>"
  echo "    <p><a href=\"subdomains/final-subdomains.txt\">final-subdomains.txt</a></p>"

  echo "    <h2>2. Takeover</h2>"
  echo "    <p><a href=\"scans/final-takeover.txt\">final-takeover.txt</a></p>"

  echo "    <h2>3. CORS</h2>"
  echo "    <p><a href=\"scans/final-cors.txt\">final-cors.txt</a></p>"

  echo "    <h2>4. Resolved IPs</h2>"
  echo "    <p><a href=\"scans/final-ips.txt\">final-ips.txt</a></p>"

  echo "    <h2>5. Aquatone</h2>"
  echo "    <p><a href=\"aquatone/aquatone_report.html\">aquatone_report.html</a></p>"

  echo "    <h2>6. Dirsearch</h2>"
  echo "    <p>Reports in <code>dirsearch/</code> with files ending in <code>_http.txt</code> and <code>_https.txt</code></p>"

  echo "    <h2>7. Masscan</h2>"
  echo "    <p><a href=\"masscan/final-masscan.html\">final-masscan.html</a></p>"
  echo "    <p><a href=\"masscan/open_ports.txt\">open_ports.txt</a></p>"

  echo "    <h2>8. Nmap</h2>"
  echo "    <ul>"
  for nmap_html in "${NMAP_DIR}"/*.html; do
    basefile=$(basename "$nmap_html")
    echo "      <li><a href=\"nmap/$basefile\">$basefile</a></li>"
  done
  echo "    </ul>"

  echo "  </body>"
  echo "</html>"
} > "${REPORT_FILE}"

echo "Final report: ${REPORT_FILE}"
echo
echo "============================================"
echo " Workflow finished successfully!"
echo " Results in: ${OUTPUT_DIR}"
echo " Main log: ${LOG_DIR}/workflow.log"
echo "============================================"
