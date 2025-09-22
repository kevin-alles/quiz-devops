#! /bin/bash

# Remove 'set -e' to prevent exit on error

# Set log file location
LOG_FILE=/tmp/uninstall.log

# Truncate log file at start
: > "$LOG_FILE"

# Redirect all output (stdout and stderr) to log file and console
exec > >(tee -a $LOG_FILE) 2>&1

# Log start time
echo "Deinstallation gestartet um $(date +"%d.%m.%Y %H:%M:%S")"

# Remove user, group, installed packages, application files, services and configurations
sudo a2dismod mpm_worker || true
sudo a2dismod mpm_prefork || true
sudo a2dismod mpm_event || true
apt-get remove -y git apache2 webhook sudo php libapache2-mod-php || true
apt-get purge -y git apache2 webhook sudo php libapache2-mod-php || true
apt autoremove -y || true
userdel quiz || true
rm -r /etc/apache2/ || true
rm -r /opt/quiz/ || true
rm -r /etc/webhook/ || true
rm -r /etc/sudoers.d/ || true

# Stop and disable services
systemctl stop quiz-backend.service || true
systemctl disable quiz-backend.service || true
systemctl stop webhook.service || true
systemctl disable webhook.service || true

# Log end time
echo "Deinstallation abgeschlossen um $(date +"%d.%m.%Y %H:%M:%S")"