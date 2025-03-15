@echo off
setlocal enabledelayedexpansion

REM Pi-hole Blocklist Downloader and Optimizer Runner for Windows
REM This script ensures all dependencies are installed and runs the downloader

REM Version
set VERSION=1.2.0

REM ANSI Color codes (works in Windows 10+)
set "ESC="
for /f %%a in ('echo prompt $E^|cmd /q') do set "ESC=%%a"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "BLUE=%ESC%[94m"
set "CYAN=%ESC%[96m"
set "WHITE=%ESC%[97m"
set "BOLD=%ESC%[1m"
set "RESET=%ESC%[0m"

REM Check Windows version for color support
ver | find "10." > nul
if %ERRORLEVEL% NEQ 0 (
    REM Not Windows 10+ or color not supported
    set "GREEN="
    set "YELLOW="
    set "RED="
    set "BLUE="
    set "CYAN="
    set "WHITE="
    set "BOLD="
    set "RESET="
)

REM Default options
set VERBOSE=false
set QUIET=false
set SCRIPT_ARGS=

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :end_parse_args
if /i "%~1"=="-v" (
    set VERBOSE=true
    set SCRIPT_ARGS=%SCRIPT_ARGS% --verbose
    shift
    goto :parse_args
)
if /i "%~1"=="--verbose" (
    set VERBOSE=true
    set SCRIPT_ARGS=%SCRIPT_ARGS% --verbose
    shift
    goto :parse_args
)
if /i "%~1"=="-q" (
    set QUIET=true
    set SCRIPT_ARGS=%SCRIPT_ARGS% --quiet
    shift
    goto :parse_args
)
if /i "%~1"=="--quiet" (
    set QUIET=true
    set SCRIPT_ARGS=%SCRIPT_ARGS% --quiet
    shift
    goto :parse_args
)
if /i "%~1"=="-h" (
    call :print_help
    exit /b 0
)
if /i "%~1"=="--help" (
    call :print_help
    exit /b 0
)
if /i "%~1"=="--version" (
    echo Pi-hole Blocklist Downloader v%VERSION%
    exit /b 0
)

REM Pass other arguments to the Python script
set SCRIPT_ARGS=%SCRIPT_ARGS% %1
shift
goto :parse_args
:end_parse_args

REM Print banner
if "%QUIET%"=="false" (
    echo.
    echo %BOLD%===============================================================================%RESET%
    echo %BOLD%                PI-HOLE BLOCKLIST DOWNLOADER v%VERSION%                       %RESET%
    echo %BOLD%===============================================================================%RESET%
    echo.
)

REM Check for python installation
call :log_info "Checking for Python installation..."

where python >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    call :log_error "Python is required but not installed."
    call :log_error "Please install Python 3.6+ from https://www.python.org/downloads/"
    call :log_error "Make sure to check 'Add Python to PATH' during installation."
    pause
    exit /b 1
)

REM Check Python version (need 3.6+)
for /f "tokens=2 delims= " %%V in ('python --version 2^>^&1') do set PYTHON_VERSION=%%V
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set PYTHON_MAJOR=%%a
    set PYTHON_MINOR=%%b
)

if %PYTHON_MAJOR% LSS 3 (
    call :log_error "Python 3.6+ is required. You have Python %PYTHON_VERSION%"
    call :log_error "Please upgrade Python from https://www.python.org/downloads/"
    pause
    exit /b 1
)

if %PYTHON_MAJOR% EQU 3 (
    if %PYTHON_MINOR% LSS 6 (
        call :log_error "Python 3.6+ is required. You have Python %PYTHON_VERSION%"
        call :log_error "Please upgrade Python from https://www.python.org/downloads/"
        pause
        exit /b 1
    )
)

call :log_debug "Using Python %PYTHON_VERSION%"

REM Check if virtual environment is valid
if exist venv (
    if not exist venv\Scripts\python.exe (
        call :log_warn "Virtual environment exists but appears to be corrupted"
        call :log_info "Removing corrupted virtual environment..."
        rmdir /s /q venv
    )
)

REM Create a virtual environment if it doesn't exist
if not exist venv (
    call :log_info "Creating Python virtual environment..."
    python -m venv venv
    if %ERRORLEVEL% NEQ 0 (
        call :log_error "Failed to create virtual environment."
        call :log_info "Trying alternative approach with virtualenv..."
        
        REM Try installing virtualenv and using it instead
        python -m pip install virtualenv
        if %ERRORLEVEL% EQU 0 (
            python -m virtualenv venv
            if %ERRORLEVEL% NEQ 0 (
                call :log_error "Failed to create virtual environment using virtualenv."
                call :log_info "Will proceed without a virtual environment."
                echo 1 > .no_venv
            )
        ) else (
            call :log_error "Failed to install virtualenv."
            call :log_info "Will proceed without a virtual environment."
            echo 1 > .no_venv
        )
    )
)

REM Activate virtual environment
if exist venv (
    if not exist .no_venv (
        call :log_info "Activating virtual environment..."
        call venv\Scripts\activate.bat
        if %ERRORLEVEL% NEQ 0 (
            call :log_warn "Failed to activate virtual environment, continuing without it..."
            echo 1 > .no_venv
        ) else (
            call :log_debug "Virtual environment activated successfully"
        )
    )
)

REM Install dependencies
call :log_info "Installing required packages..."
if exist .no_venv (
    python -m pip install --user requests tqdm
) else (
    python -m pip install requests tqdm
)

REM Check if pip install succeeded
if %ERRORLEVEL% NEQ 0 (
    call :log_warn "Failed to install Python dependencies. Some features may not work correctly."
)

REM Check if the configuration file exists
if not exist blocklists.conf (
    call :log_info "Configuration file not found, creating from the example file..."
    if exist blocklists.conf.example (
        copy blocklists.conf.example blocklists.conf
        call :log_success "Created configuration file from example template."
    ) else if exist pihole-blocklist-config.txt (
        copy pihole-blocklist-config.txt blocklists.conf
        call :log_success "Created configuration file from template."
    ) else (
        call :log_warn "No configuration template found, creating a basic one..."
        
        REM Create a basic configuration file
        echo # Pi-hole Blocklist Configuration > blocklists.conf
        echo # Format: url^|name^|category >> blocklists.conf
        echo # Categories: advertising, tracking, malicious, suspicious, nsfw, comprehensive >> blocklists.conf
        echo # Lines starting with # are comments and will be ignored >> blocklists.conf
        echo. >> blocklists.conf
        echo # Sample comprehensive blocklists >> blocklists.conf
        echo https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts^|stevenblack_unified^|comprehensive >> blocklists.conf
        echo https://big.oisd.nl^|oisd_big^|comprehensive >> blocklists.conf
        echo. >> blocklists.conf
        echo # Sample advertising blocklists >> blocklists.conf
        echo https://adaway.org/hosts.txt^|adaway^|advertising >> blocklists.conf
        echo https://v.firebog.net/hosts/AdguardDNS.txt^|adguard_dns^|advertising >> blocklists.conf
        
        call :log_success "Created basic configuration file with sample entries."
        call :log_info "Edit blocklists.conf to add more blocklists if needed."
    )
)

REM Run the Python script
call :log_info "Running Pi-hole Blocklist Downloader..."
if exist .no_venv (
    python pihole_downloader.py %SCRIPT_ARGS%
) else (
    venv\Scripts\python pihole_downloader.py %SCRIPT_ARGS%
)

REM Check if the script executed successfully
set EXIT_CODE=%ERRORLEVEL%
if %EXIT_CODE% EQU 0 (
    call :log_success "Pi-hole Blocklist Downloader completed successfully!"
    call :log_info "The optimized blocklists are ready for use with Pi-hole."
    
    REM Show the production directory
    if exist pihole_blocklists_prod (
        set count=0
        for %%F in (pihole_blocklists_prod\*.txt) do set /a count+=1
        
        call :log_info "[LIST] !count! production blocklists are available in:"
        echo   [DIR] %BOLD%%CD%\pihole_blocklists_prod\%RESET%
        
        REM Show the production list index if it exists
        if exist pihole_blocklists_prod\_production_lists.txt (
            echo.
            call :log_info "[STATS] Production list details:"
            echo %CYAN%-------------------------------------------------------------------%RESET%
            type pihole_blocklists_prod\_production_lists.txt
            echo %CYAN%-------------------------------------------------------------------%RESET%
        )
        
        echo.
        call :log_info "You can copy them to your Pi-hole's custom list directory."
    )
) else (
    call :log_error "Pi-hole Blocklist Downloader encountered errors. (Exit code: %EXIT_CODE%)"
    call :log_error "Please check the logs for more information."
)

REM Deactivate virtual environment if it was activated
if exist venv (
    if not exist .no_venv (
        call venv\Scripts\deactivate.bat
    )
)

if "%QUIET%"=="false" (
    echo.
    echo %BOLD%===============================================================================%RESET%
    echo %BOLD%                             COMPLETE                                         %RESET%
    echo %BOLD%===============================================================================%RESET%
    echo.
    pause
)

exit /b %EXIT_CODE%

REM ===== Helper Functions =====

:log_info
if "%QUIET%"=="false" (
    echo %BLUE%[INFO]%RESET% %~1
)
exit /b 0

:log_success
if "%QUIET%"=="false" (
    echo %GREEN%[SUCCESS]%RESET% %~1
)
exit /b 0

:log_warn
if "%QUIET%"=="false" (
    echo %YELLOW%[WARNING]%RESET% %~1
)
exit /b 0

:log_error
echo %RED%[ERROR]%RESET% %~1 1>&2
exit /b 0

:log_debug
if "%VERBOSE%"=="true" (
    if "%QUIET%"=="false" (
        echo %CYAN%[DEBUG]%RESET% %~1
    )
)
exit /b 0

:print_help
echo Usage: %~n0 [options]
echo.
echo Options:
echo   -v, --verbose     Enable verbose output
echo   -q, --quiet       Suppress all output except errors
echo   -h, --help        Display this help message and exit
echo   --version         Display version information and exit
echo.
echo All other options are passed to the Python script.
echo For detailed Python script options, run: %~n0 --help
exit /b 0