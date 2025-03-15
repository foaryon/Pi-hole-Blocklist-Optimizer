# Pi-hole Blocklist Downloader and Optimizer

A powerful tool for downloading, optimizing, and organizing Pi-hole blocklists.

## Features

- **External Configuration**: Blocklists are defined in an external configuration file, making it easy to add, remove, or disable lists
- **Multi-Format Support**: Handles all common blocklist formats:
  - Standard hosts format (`0.0.0.0 domain.com`)
  - AdBlock syntax (`||domain.com^`)
  - Plain domain lists
- **Format Preservation**: Intelligently preserves the original format of well-structured lists
- **Metadata Retention**: Keeps valuable metadata from source lists (title, version, modification date)
- **Grouping Support**: Maintains logical grouping from source lists
- **Domain Validation**: Ensures all entries are valid domains
- **Duplicate Handling**: Identifies and removes duplicate domains
- **Parallel Processing**: Multi-threaded downloading for faster operation
- **Production Lists**: Creates optimized combined lists for each category
- **Detailed Statistics**: Provides comprehensive information about downloaded lists
- **Error Recovery**: Automatically comments out failed lists in the configuration file

## Requirements

- Python 3.6+
- Required Python packages:
  - requests
  - tqdm

## Installation

1. Clone or download this repository:

```bash
git clone https://github.com/zachlagden/Pi-hole-Blocklist-Optimizer
cd pihole-blocklist-downloader
```

2. Set up a virtual environment and install dependencies:

```bash
python3 -m venv venv
source venv/bin/activate
pip install requests tqdm
```

3. Ensure the script is executable:

```bash
chmod +x pihole_download.sh
```

## Configuration

The blocklists are defined in `blocklists.conf`. Each line follows this format:

```
url|name|category
```

For example:

```
https://adaway.org/hosts.txt|adaway|advertising
```

- **url**: The URL of the blocklist
- **name**: A descriptive name (used for the filename)
- **category**: The category of the blocklist (advertising, tracking, malicious, etc.)

Lines starting with `#` are comments and will be ignored. Lists that failed to download will be automatically commented out with `#DISABLED:`.

## Usage

### Basic Usage

```bash
./pihole_download.sh
```

This will download and optimize all blocklists defined in `blocklists.conf`.

### Advanced Usage

You can run the Python script directly with additional options:

```bash
python3 pihole_downloader.py --threads 8 --verbose
```

### Command Line Options

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

## Directory Structure

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

## Using with Pi-hole

The optimized lists in `pihole_blocklists_prod/` are ready to be used with Pi-hole. You can:

1. Host them on your own web server and add the URLs to Pi-hole
2. Add them as local files to Pi-hole's custom list directory
3. Use them as references to create your own curated blocklists

## Maintenance

- To add new blocklists, edit `blocklists.conf` and add new entries in the format `url|name|category`
- To disable a specific list, add `#` at the beginning of the line
- Failed lists will be automatically commented out with `#DISABLED:` for your review

## Troubleshooting

- Check the log file `pihole_downloader.log` for detailed information about any errors
- If a list consistently fails, check if the URL is still valid
- For any issues with specific blocklists, consult the `blocklist_stats.txt` file for error details

## License

This project is licensed under the MIT License - see the LICENSE file for details.