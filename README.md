# Pi-hole Blocklist Downloader and Optimizer

<div align="center">

![GitHub release (latest by date)](https://img.shields.io/github/v/release/zachlagden/Pi-hole-Blocklist-Optimizer?style=flat-square)
![GitHub](https://img.shields.io/github/license/zachlagden/Pi-hole-Blocklist-Optimizer?style=flat-square)
![Python Version](https://img.shields.io/badge/python-3.6%2B-blue?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20macOS-lightgrey?style=flat-square)
![Stars](https://img.shields.io/github/stars/zachlagden/Pi-hole-Blocklist-Optimizer?style=flat-square)
[![Maintenance](https://img.shields.io/badge/Maintained-yes-green.svg?style=flat-square)](https://github.com/zachlagden/Pi-hole-Blocklist-Optimizer/graphs/commit-activity)

**A powerful and efficient tool for downloading, optimizing, and organizing blocklists for [Pi-hole](https://pi-hole.net/)**

[Key Features](#key-features) •
[Installation](#installation) •
[Quick Start](#quick-start) •
[Configuration](#configuration) •
[Usage](#usage) •
[Documentation](#usage) •
[Contributing](#contributing)

</div>

## 📋 Table of Contents

- [What Does This Tool Do?](#what-does-this-tool-do)
- [Key Features](#key-features)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Output Directory Structure](#output-directory-structure)
- [Using with Pi-hole](#using-with-pi-hole)
- [Performance Notes](#performance-notes)
- [Screenshots](#screenshots)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## 🔍 What Does This Tool Do?

This tool helps you maintain comprehensive blocklists for Pi-hole by:

1. **Downloading** blocklists from multiple sources
2. **Optimizing** them by removing duplicates and invalid entries
3. **Organizing** them into categories (advertising, tracking, malicious, etc.)
4. **Combining** them into ready-to-use production lists

<div align="center">
  <img src="https://raw.githubusercontent.com/zachlagden/Pi-hole-Blocklist-Optimizer/assets/workflow.png" alt="Pi-hole Blocklist Optimizer Workflow" width="600">
</div>

## ✨ Key Features

- **External Configuration**: Blocklists are defined in an external configuration file for easy management
- **Multi-Format Support**: Handles all common blocklist formats:
  - Standard hosts format (`0.0.0.0 domain.com`)
  - AdBlock syntax (`||domain.com^`)
  - Plain domain lists
- **Intelligent Processing**:
  - Preserves the original format of well-structured lists
  - Retains valuable metadata (title, version, modification date)
  - Maintains logical grouping from source lists
- **Quality Control**:
  - Validates all entries as proper domains
  - Removes duplicate domains across all lists
- **Performance Optimized**:
  - Multi-threaded downloading for faster operation
  - Efficient memory usage even with millions of domains
- **Production-Ready Output**:
  - Creates optimized combined lists for each category
  - Generates a master list of all unique domains
- **Detailed Reporting**:
  - Provides comprehensive statistics about downloaded lists
  - Tracks successful and failed downloads
- **Error Recovery**:
  - Automatically comments out failed lists in the configuration file
  - Continues processing despite individual list failures

## 💻 System Requirements

- Python 3.6 or higher
- Required Python packages (automatically installed by the wrapper scripts):
  - requests
  - tqdm

## 📥 Installation

### Option 1: Direct Download

1. Clone the repository:

```bash
git clone https://github.com/zachlagden/Pi-hole-Blocklist-Optimizer
cd Pi-hole-Blocklist-Optimizer
```

2. Make the scripts executable (Linux/macOS only):

```bash
chmod +x pihole_download.sh
```

### Option 2: Manual Installation

1. Download or copy these files:
   - `pihole_downloader.py` (Main Python script)
   - `pihole_download.sh` (Linux/macOS wrapper script)
   - `pihole_download.bat` (Windows wrapper script)
   - `blocklists.conf` (Configuration file)
   
2. Ensure you have Python 3.6+ installed
   
3. Install the required dependencies:

```bash
pip install requests tqdm
```

## 🚀 Quick Start

**Linux/macOS:**
```bash
./pihole_download.sh
```

**Windows:**
```
pihole_download.bat
```

That's it! The script will:
1. Create necessary directories
2. Download blocklists from the configuration file
3. Optimize and categorize them
4. Create production-ready lists in `pihole_blocklists_prod/`

## ⚙️ Configuration

The blocklists are defined in `blocklists.conf`. Each line has this format:

```
url|name|category
```

For example:

```
https://adaway.org/hosts.txt|adaway|advertising
```

Where:
- **url**: The URL of the blocklist
- **name**: A descriptive name (used for the filename)
- **category**: The category of the blocklist (advertising, tracking, malicious, etc.)

Lines starting with `#` are comments and will be ignored. Lists that failed to download will be automatically commented out with `#DISABLED:`.

### Customizing Categories

The default configuration includes these categories:
- `advertising`: Ad networks and services
- `tracking`: User tracking and analytics
- `malicious`: Malware, phishing, and scam sites
- `suspicious`: Potentially unwanted content
- `nsfw`: Adult content
- `comprehensive`: Multi-category lists

You can add your own categories by simply using them in the configuration file.

## 🛠️ Usage

### Basic Usage

**Linux/macOS:**
```bash
./pihole_download.sh
```

**Windows:**
```
pihole_download.bat
```

### Advanced Options

You can run the Python script directly with additional options:

```bash
python3 pihole_downloader.py --threads 8 --verbose
```

### Command Line Arguments

```
usage: pihole_downloader.py [-h] [-c CONFIG] [-b BASE_DIR] [-p PROD_DIR] [-t THREADS] [--skip-download] [--skip-optimize] [-v] [-q]

Pi-hole Blocklist Downloader and Optimizer

options:
  -h, --help            show this help message and exit
  -c CONFIG, --config CONFIG
                        Configuration file (default: blocklists.conf)
  -b BASE_DIR, --base-dir BASE_DIR
                        Base directory for raw and optimized lists (default: pihole_blocklists)
  -p PROD_DIR, --prod-dir PROD_DIR
                        Production directory for combined lists (default: pihole_blocklists_prod)
  -t THREADS, --threads THREADS
                        Number of download threads (default: 4)
  --skip-download       Skip downloading files (use existing files)
  --skip-optimize       Skip optimization (just download)
  -v, --verbose         Enable verbose logging
  -q, --quiet           Suppress all output except errors
```

## 📁 Output Directory Structure

The tool creates the following directory structure:

```
pihole_blocklists/
├── advertising/      # Individual advertising blocklists
├── tracking/         # Individual tracking blocklists
├── malicious/        # Individual malicious/security blocklists
├── suspicious/       # Individual suspicious blocklists
├── nsfw/             # Individual NSFW blocklists
└── comprehensive/    # Individual comprehensive blocklists
pihole_blocklists_prod/
├── all_domains.txt   # Combined list of all unique domains
├── advertising.txt   # Combined advertising domains
├── tracking.txt      # Combined tracking domains
├── malicious.txt     # Combined malicious domains
├── suspicious.txt    # Combined suspicious domains
└── nsfw.txt          # Combined NSFW domains
```

## 🔄 Using with Pi-hole

The optimized lists in `pihole_blocklists_prod/` are ready to be used with Pi-hole. You can:

### Option 1: Use Remote Lists (Recommended)

Host the files on a web server and add the URLs to Pi-hole's blocklist settings.

### Option 2: Use Local Files

Copy the files to Pi-hole's custom list directory:

```bash
# On your Pi-hole device
sudo cp pihole_blocklists_prod/*.txt /etc/pihole/
sudo pihole restartdns
```

### Option 3: Create Your Own Curated Lists

Use these files as a reference to create your own specialized blocklists based on your needs.

## ⚡ Performance Notes

- The default configuration includes ~50 blocklists with over 6 million unique domains
- Processing all lists typically takes 60-90 seconds on modern hardware
- Memory usage scales with the number of domains (expect ~1GB for full processing)
- For low-memory systems, consider processing fewer lists or categories

## 📸 Screenshots

<div align="center">
  <img src="https://raw.githubusercontent.com/zachlagden/Pi-hole-Blocklist-Optimizer/assets/screenshot1.png" alt="Pi-hole Blocklist Optimizer Screenshot" width="600">
</div>

## 🔧 Troubleshooting

### Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| **Connection Errors** | Check your internet connection and proxy settings |
| **Memory Errors** | Reduce the number of lists or increase available memory |
| **Permission Errors** | Ensure you have write permissions in the script directory |
| **Python Errors** | Make sure you have Python 3.6+ and required packages installed |

### Detailed Logs
Check `pihole_downloader.log` for detailed information about any errors.

### Failed Lists
Lists that fail to download will be commented out in the configuration file with `#DISABLED:` prefix.

### Statistics
Review `pihole_blocklists/blocklist_stats.txt` for detailed statistics and error information.

## 👥 Contributing

Contributions are welcome! Here's how you can help:

1. **Report bugs or suggest features** by opening an issue
2. **Fix bugs or implement features** by submitting a pull request
3. **Improve documentation** by submitting updates to the README or other docs
4. **Share the project** with others who might find it useful

### Development Setup

```bash
# Clone the repository
git clone https://github.com/zachlagden/Pi-hole-Blocklist-Optimizer
cd Pi-hole-Blocklist-Optimizer

# Set up a virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install requests tqdm
```

## 📜 License

This project is licensed under the Unlicense - see the [UNLICENCE](UNLICENCE) file for details. This means you are free to use, modify, distribute, and do whatever you want with this software with no restrictions.

## 🙏 Acknowledgements

- This tool builds upon the great work of various blocklist maintainers listed in the configuration file
- Special thanks to the Pi-hole team for creating such a useful ad-blocking tool