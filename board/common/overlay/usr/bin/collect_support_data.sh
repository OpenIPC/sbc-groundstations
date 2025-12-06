#!/bin/sh

# Support Data Collection Script for Buildroot Devices
# Creates a zip file with system information for troubleshooting

set -e

# Configuration
COLLECTION_DIR="/tmp/support_data_$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="/media/dvr"
SCRIPT_NAME="collect_support_data.sh"
OUTPUT_PREFIX="openipc_support_data"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_PREFIX}_${TIMESTAMP}.zip"
MAX_LOG_SIZE=1048576  # 1MB max per log file

# Colors for output (if supported)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create collection directory
mkdir -p "${COLLECTION_DIR}"
cd "${COLLECTION_DIR}"

echo_colored() {
    echo -e "${2}${1}${NC}"
}

collect_file() {
    local src="$1"
    local dest="$2"
    
    if [ -e "$src" ]; then
        cp "$src" "$dest" 2>/dev/null || {
            echo "Warning: Could not copy $src" >&2
            echo "Permission denied or file busy" > "$dest.access_error"
        }
    else
        echo "File not found: $src" > "$dest.not_found"
    fi
}

collect_log() {
    local log_path="$1"
    local dest_name="$2"
    
    if [ -f "$log_path" ]; then
        local size=$(stat -c%s "$log_path" 2>/dev/null || echo "0")
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            echo "Log truncated (original: ${size} bytes)" > "${dest_name}"
            tail -c "${MAX_LOG_SIZE}" "$log_path" >> "${dest_name}"
            echo "" >> "${dest_name}"
            echo "... [truncated] ..." >> "${dest_name}"
            head -c 10240 "$log_path" >> "${dest_name}"
        else
            cp "$log_path" "${dest_name}" 2>/dev/null || {
                echo "Could not copy log: $log_path" > "${dest_name}.error"
            }
        fi
    fi
}

echo_colored "Starting support data collection..." "$GREEN"
echo_colored "Output will be saved to: ${OUTPUT_FILE}" "$YELLOW"

# 1. SYSTEM INFORMATION
echo_colored "Collecting system information..." "$GREEN"
mkdir -p system_info

# Basic system info
uname -a > system_info/uname.txt 2>&1
cat /proc/version > system_info/proc_version.txt 2>&1
cat /etc/os-release 2>/dev/null > system_info/os_release.txt || echo "No os-release found" > system_info/os_release.txt
cat /etc/issue 2>/dev/null > system_info/issue.txt || echo "No issue file found" > system_info/issue.txt

# CPU/Memory info
cat /proc/cpuinfo > system_info/cpuinfo.txt 2>&1
cat /proc/meminfo > system_info/meminfo.txt 2>&1
free -h > system_info/free.txt 2>&1

# Uptime and load
uptime > system_info/uptime.txt 2>&1
cat /proc/loadavg > system_info/loadavg.txt 2>&1

# 2. HARDWARE INFORMATION
echo_colored "Collecting hardware information..." "$GREEN"
mkdir -p hardware

# PCI and USB devices
lspci 2>/dev/null > hardware/lspci.txt || echo "lspci not available" > hardware/lspci.txt
lsusb 2>/dev/null > hardware/lsusb.txt || echo "lsusb not available" > hardware/lsusb.txt

# Block devices and mounts
blkid 2>/dev/null > hardware/blkid.txt || echo "blkid not available" > hardware/blkid.txt
df -h > hardware/df.txt 2>&1
mount > hardware/mount.txt 2>&1
cat /proc/mounts > hardware/proc_mounts.txt 2>&1

# Network interfaces
ip link show > hardware/network_interfaces.txt 2>&1
ip addr show > hardware/ip_addr.txt 2>&1

# 3. KERNEL AND DRIVERS
echo_colored "Collecting kernel and driver information..." "$GREEN"
mkdir -p kernel

# Kernel modules
lsmod 2>/dev/null > kernel/lsmod.txt || echo "lsmod not available" > kernel/lsmod.txt
cat /proc/modules 2>/dev/null > kernel/proc_modules.txt || echo "No /proc/modules" > kernel/proc_modules.txt

# Kernel messages
dmesg > kernel/dmesg.txt 2>&1
tail -n 1000 /var/log/kern.log 2>/dev/null > kernel/kern_log.txt || echo "No kern.log" > kernel/kern_log.txt

# Kernel parameters
cat /proc/cmdline > kernel/cmdline.txt 2>&1
sysctl -a 2>/dev/null > kernel/sysctl.txt || echo "sysctl not available" > kernel/sysctl.txt

# 4. NETWORK INFORMATION
echo_colored "Collecting network information..." "$GREEN"
mkdir -p network

# Network configuration
ip route show > network/route.txt 2>&1
cat /etc/resolv.conf 2>/dev/null > network/resolv.conf || echo "No resolv.conf" > network/resolv.conf
cat /etc/hosts 2>/dev/null > network/hosts || echo "No hosts file" > network/hosts

# Network connections
ss -tulnp 2>/dev/null > network/ss.txt || netstat -tulnp 2>/dev/null > network/netstat.txt || echo "No network stat tool" > network/netstat.txt

# Firewall rules
iptables -L -n -v 2>/dev/null > network/iptables.txt || echo "iptables not available" > network/iptables.txt

# Wlan devices
iw dev 2>/dev/null > network/iw.txt || echo "iw not available" > network/iw.txt

# 5. PROCESS INFORMATION
echo_colored "Collecting process information..." "$GREEN"
mkdir -p processes

ps aux > processes/ps_aux.txt 2>&1
top -b -n 1 > processes/top.txt 2>&1

# Service status (if systemd or init.d)
if command -v systemctl >/dev/null 2>&1; then
    systemctl list-units --type=service > processes/services.txt 2>&1
    systemctl status > processes/systemctl_status.txt 2>&1
elif [ -d "/etc/init.d" ]; then
    ls -la /etc/init.d/ > processes/initd_services.txt 2>&1
fi

# 6. LOG FILES
echo_colored "Collecting log files..." "$GREEN"
mkdir -p logs

# System logs
collect_log "/var/log/messages" "logs/messages.log"
collect_log "/var/log/syslog" "logs/syslog.log"
collect_log "/var/log/dmesg" "logs/dmesg.log"
collect_log "/var/log/auth.log" "logs/auth.log"
collect_log "/var/log/daemon.log" "logs/daemon.log"

# Application logs (common locations)
for log in /var/log/*.log; do
    if [ -f "$log" ]; then
        base_name=$(basename "$log")
        collect_log "$log" "logs/${base_name}"
    fi
done

# 7. CONFIGURATION FILES
echo_colored "Collecting configuration files..." "$GREEN"
mkdir -p configs

# Common config files
collect_file "/etc/fstab" "configs/fstab"
collect_file "/etc/network/interfaces" "configs/network_interfaces"
for file in /etc/network/interfaces.d/*; do
    mkdir -p configs/network_interfaces.d/
    collect_file "$file" "configs/network_interfaces.d/$(basename $file)"
done
for file in /etc/*wpa*.conf; do
    psk=$(grep -o 'psk="[^"]*"' "$file" | sed 's/psk="//;s/"//')
    if [ -n "$psk" ]; then
        psk_hash=$(echo -n "$psk" | sha256sum | cut -d" " -f1)
        sed "s/psk=\"$psk\"/psk=\"sha256sum($psk_hash)\"/" "$file" > "configs/$(basename $file)"
    fi
done
collect_file "/etc/hostname" "configs/hostname"
collect_file "/etc/timezone" "configs/timezone"
collect_file "/etc/passwd" "configs/passwd"
collect_file "/etc/group" "configs/group"
collect_file "/etc/shadow" "configs/shadow"
collect_file "/etc/shells" "configs/shells"

# Buildroot specific
collect_file "/etc/buildroot-version" "configs/buildroot_version"
collect_file "/etc/buildroot-build" "configs/buildroot_build"

# 8. PACKAGE INFORMATION
echo_colored "Collecting package information..." "$GREEN"
mkdir -p packages

# 9. ENVIRONMENT VARIABLES
echo_colored "Collecting environment information..." "$GREEN"
mkdir -p environment

env > environment/env.txt 2>&1
set > environment/set.txt 2>&1
printenv > environment/printenv.txt 2>&1

# 10. CUSTOM CHECKS
echo_colored "Running custom checks..." "$GREEN"
mkdir -p custom_checks

# Disk usage
du -sh / 2>/dev/null | head -5 > custom_checks/disk_usage.txt || true

# Inode usage
df -i > custom_checks/inode_usage.txt 2>&1

# List filesysten
find / 2>/dev/null > custom_checks/file_list.txt

# 11. CREATE SUMMARY REPORT
echo_colored "Creating summary report..." "$GREEN"
cat > summary_report.txt << EOF
SUPPORT DATA COLLECTION REPORT
=============================
Collection Time: $(date)
Hostname: $(hostname 2>/dev/null || echo 'unknown')
Kernel: $(uname -r)
Architecture: $(uname -m)

SYSTEM OVERVIEW:
- Uptime: $(uptime -p 2>/dev/null || cat /proc/uptime | awk '{print int($1/86400)" days "int(($1%86400)/3600)" hours"}')
- Load Average: $(cat /proc/loadavg 2>/dev/null || echo 'N/A')
- Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')
- Storage: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')

NETWORK:
- Interfaces: $(ip link show | grep -c '^[0-9]:')
- IP Addresses: $(ip addr show | grep -c 'inet ')

PROCESSES:
- Total: $(ps aux | wc -l)
- Users: $(ps aux | awk '{print $1}' | sort -u | wc -l)

COLLECTED DATA:
- System Info: $(ls -1 system_info/ 2>/dev/null | wc -l) files
- Hardware Info: $(ls -1 hardware/ 2>/dev/null | wc -l) files
- Kernel Info: $(ls -1 kernel/ 2>/dev/null | wc -l) files
- Network Info: $(ls -1 network/ 2>/dev/null | wc -l) files
- Log Files: $(ls -1 logs/ 2>/dev/null | wc -l) files
- Configuration: $(ls -1 configs/ 2>/dev/null | wc -l) files

NOTES:
This archive contains troubleshooting data from your device.
Share this file with support for assistance.

EOF

# 12. CREATE README
cat > README.txt << 'EOF'
DEVICE SUPPORT DATA COLLECTION
==============================

This archive contains system information collected for troubleshooting purposes.

CONTENTS:
1. system_info/      - Basic system information
2. hardware/         - Hardware and device information
3. kernel/           - Kernel and driver information
4. network/          - Network configuration and status
5. processes/        - Running processes and services
6. logs/             - System and application logs
7. configs/          - Configuration files
8. packages/         - Installed package information
9. environment/      - Environment variables
10. custom_checks/   - Additional diagnostic checks

FILES:
- summary_report.txt - Overview of collected data
- collection_script.sh - Copy of the collection script

SECURITY NOTES:
- This archive may contain sensitive information
- Review contents before sharing
- The script does not collect:
  * Personal user files
  * Browser history
  * Passwords (except hashed from /etc/shadow)
  * Encryption keys

EOF

# 13. SAVE THE SCRIPT ITSELF
cp "$0" "${COLLECTION_DIR}/collection_script.sh"

# 14. CREATE ZIP ARCHIVE
echo_colored "Creating archive: ${OUTPUT_FILE}" "$GREEN"
cd "${COLLECTION_DIR}/.."
if command -v zip >/dev/null 2>&1; then
    zip -rq "${OUTPUT_FILE}" "$(basename ${COLLECTION_DIR})"
    echo_colored "Archive created successfully!" "$GREEN"
    echo_colored "Size: $(du -h ${OUTPUT_FILE} | cut -f1)" "$YELLOW"
    echo_colored "Please upload this file to support: ${OUTPUT_FILE}" "$YELLOW"
else
    echo_colored "Warning: zip command not found. Creating tar archive instead." "$YELLOW"
    OUTPUT_FILE="${OUTPUT_FILE%.zip}.tar.gz"
    tar -cf - "$(basename ${COLLECTION_DIR})" | gzip -9 > "${OUTPUT_FILE}"
    echo_colored "Archive created: ${OUTPUT_FILE}" "$GREEN"
fi

# 15. CLEANUP
echo_colored "Cleaning up temporary files..." "$GREEN"
rm -rf "${COLLECTION_DIR}"

# 16. FINAL INSTRUCTIONS
cat << EOF

============================================
SUPPORT DATA COLLECTION COMPLETE
============================================
Archive created: ${OUTPUT_FILE}

NEXT STEPS:
1. Check the file size is reasonable (typically 1-10MB)
2. Review the contents if privacy is a concern
3. Upload to your support portal
4. Provide this filename with your support request

EOF

exit 0