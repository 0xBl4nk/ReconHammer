# ReconHammer (!!!BETA TESTING!!!)

ReconHammer is a comprehensive automated reconnaissance workflow designed to streamline various security assessment tasks. It integrates multiple open-source tools to perform subdomain enumeration, takeover checking, CORS scanning, DNS resolution, screenshot capture, directory scanning, port scanning, service enumeration, and final report generation—all in one go.

## Features

- **Customizable Parameters:**
  - `--threads <NUM>`: Set the number of threads (default: 5).
  - `--vuln`: Enable Nmap vulnerability scripts during scanning.
  - `--verbose`: Display detailed output for tools like subfinder.

- **Dependency Checks:**  
  The script ensures all required tools are installed and available in your `PATH`.

- **Integrated Recon Tools:**
  - **Subdomain Enumeration:** Uses *amass* and *subfinder*.
  - **Subdomain Takeover:** Uses *subjack*.
  - **CORS Scanning:** Runs the included `cors_scan.py` (located in `./CORScanner`).
  - **DNS Resolution:** Uses *massdns*.
  - **Screenshot Capture:** Utilizes *aquatone*.
  - **Directory Scanning:** Employs *dirsearch* (via GNU Parallel).
  - **Port Scanning:** Performs scanning with *masscan*.
  - **Service Enumeration:** Groups open ports and runs *nmap* (with optional vulnerability checks).

- **Report Generation:**  
  Creates a final HTML report that consolidates the results from all stages.

## Requirements

Before using ReconHammer, ensure the following tools and files are installed and accessible:

- **Command-Line Tools:**
  - `amass`
  - `subfinder`
  - `subjack`
  - `massdns`
  - `aquatone`
  - `masscan`
  - `nmap`
  - `parallel` (GNU Parallel)
  - `xsltproc`
  - `python3`

- **External Scripts:**
  - `./CORScanner/cors_scan.py`
  - `./dirsearch/dirsearch.py`

- **Included Files:**
  - `resolvers.txt`: A list of DNS resolvers for massdns.
  - `directory-list-2.3-medium.txt`: Wordlist for dirsearch.

> **Note:** Ensure that `cors_scan.py` and `dirsearch.py` are in the correct directories (`./CORScanner/` and `./dirsearch/`, respectively).

## Installation and Setup

1. **Clone or Download the Repository:**

   ```bash
   git clone https://github.com/0xBl4nk/ReconHammer.git
   cd ReconHammer
   ```
2. **Verify Dependencies:**
    Make sure all the required tools listed above are installed and in your system's PATH.

    Place Additional Files:
        Verify that `cors_scan.py` is in the `./CORScanner/` directory.
        Verify that `dirsearch.py` is in the `./dirsearch/` directory.
        Place `resolvers.txt` and `directory-list-2.3-medium.txt` in the root directory of the project (or adjust the paths in the script if necessary).

## Usage

Run the script from the command line. It requires at least the target domain as an argument. The basic syntax is:

```
./ReconHammer.sh <domain> [--threads <NUM>] [--vuln] [--verbose]
```

### Examples

- Basic Execution:

```
./ReconHammer.sh example.com
```

- Specify Number of Threads (e.g., 10):

```
./ReconHammer.sh example.com --threads 10
```

Enable Nmap Vulnerability Scan and Verbose Output:

```
./ReconHammer.sh example.com --vuln --verbose
```

> **Tip**: The script performs a basic validation on the provided domain. Ensure you use a valid domain (e.g., example.com).

Directory Structure

Upon execution, ReconHammer creates a results directory (e.g., results_example.com) with the following structure:

```
results_example.com/
├── subdomains/
│   ├── amass.txt
│   ├── subfinder.txt
│   └── final-subdomains.txt
├── scans/
│   ├── final-takeover.txt
│   ├── final-cors.txt
│   ├── massdns_input.txt
│   ├── massdns_output.txt
│   ├── combined_ips.txt
│   └── final-ips.txt
├── aquatone/
│   └── (Aquatone screenshot results)
├── masscan/
│   ├── masscan_output.json
│   ├── open_ports.txt
│   └── final-masscan.html
├── nmap/
│   ├── (Nmap XML and HTML output files)
├── dirsearch/
│   └── (Dirsearch output files with _http.txt and _https.txt suffixes)
└── logs/
    └── workflow.log (and other error logs)
```

## Workflow Overview

1. Subdomain Enumeration:
    Uses amass and subfinder to generate a consolidated list of subdomains (final-subdomains.txt).

2.  Subdomain Takeover Check:
    Runs subjack to identify potential subdomain takeover vulnerabilities.

3. CORS Scanning:
    Executes the CORS scanner (cors_scan.py) against the identified subdomains.

3. DNS Resolution:
    Uses massdns to resolve subdomains into IP addresses, outputting a list (final-ips.txt).

4. Screenshot Capture:
    Captures screenshots of subdomains using aquatone.

5. Directory Scanning:
    Performs directory brute-forcing with dirsearch on both HTTP and HTTPS endpoints, running tasks in parallel.

6. Port Scanning:
    Uses masscan to scan all ports on the discovered IPs and filter for open ports.

7. Service Enumeration:
    Groups open ports by IP and uses nmap to perform detailed service enumeration (with optional vulnerability scripts).

8. Report Generation:
    Compiles all results into a final HTML report with links to the various outputs.

## Logs and Reports

- Logs:
    All execution and error logs are saved in the logs/ directory within the results folder (e.g., results_example.com/logs/workflow.log).

- Final Report:
    A consolidated HTML report (e.g., results_example.com/report.html) is generated with links to the outputs from each stage.

Author and Credits

- Author: 0xBl4nk
- Credits:
    This script integrates a variety of open-source tools commonly used in security reconnaissance and penetration testing.
  - https://github.com/owasp-amass/amass
  - https://github.com/projectdiscovery/subfinder
  - https://github.com/haccer/subjack
  - https://github.com/blechschmidt/massdns
  - https://github.com/michenriksen/aquatone
  - https://github.com/robertdavidgraham/masscan
  - https://github.com/chenjj/CORScanner
  - https://github.com/maurosoria/dirsearch
  - https://nmap.org/
  - https://www.gnu.org/software/parallel/
  - http://xmlsoft.org/xslt/xsltproc.html

---

