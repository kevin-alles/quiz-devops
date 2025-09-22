#! /bin/bash

set -e

# Set log file location
LOG_FILE=/tmp/uninstall.log

# Truncate log file at start
: > "$LOG_FILE"

# Redirect all output (stdout and stderr) to log file and console
exec > >(tee -a $LOG_FILE) 2>&1

# Log start time
echo "Deinstallation gestartet um $(date +"%d.%m.%Y %H:%M:%S")"

# Remove user, group, installed packages, application files, services and configurations
sudo apt purge -y apache2 php libapache2-mod-php git webhook sudo
userdel quiz
rm -r /etc/apache2/
rm -r /opt/quiz/
rm -r /etc/webhook/
rm -r /etc/sudoers.d/
apt autoremove -y

# Stop and disable services
systemctl stop quiz-backend.service || true
systemctl disable quiz-backend.service || true
systemctl stop webhook.service || true
systemctl disable webhook.service || true

# Log end time
echo "Deinstallation abgeschlossen um $(date +"%d.%m.%Y %H:%M:%S")"