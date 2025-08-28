# Tissue
Tissue is a bash file to automate basic web-application vulnerabitliy(path traversal,Cache Deception Check ,CVEs, misconfig, exposures)

## Features
---
| Category                   | Tools Used                       | Purpose                                        |
|---------------------------|----------------------------------|-----------------------------------------------|
| **Subdomain Enumeration**  | `amass`, `assetfinder`          | Discover hidden subdomains.                   |
| **Live Host Discovery**    | `httpx`                         | Check which domains are alive.                |
| **URL Crawling**           | `katana`, `gau`                 | Enumerate URLs/endpoints.                     |
| **Parameter Discovery**    | `grep`                          | Identify parameterized URLs.                  |
| **Vulnerability Templates**| `nuclei`                        | Scan for CVEs, misconfigs, exposures.         |
| **XSS & SQLi Testing**     | `dalfox` (manual review)        | Actively fuzz for XSS/SQLi.                   |
| **Path Traversal Fuzzing** | `ffuf`                          | Test for LFI/Path Traversal.                  |
| **Cache Deception**        | `curl`                          | Detect caching flaws.                         |
| **Request Smuggling**      | `curl`                          | Detect request smuggling indicators.          |
| **Misconfigured Ports**    | `nmap`                          | Scan top 1000 ports with NSE scripts.         |

---

## Installation

Clone the repository and make the script executable:

```bash
git clone https://github.com/slvignesh05/tissue.git
cd tissue
chmod +x tissue.sh
```
## Usage
-f: File containing target URLs

-o: Directory to store results

`./tissue.sh -f urls.txt -o output/`
