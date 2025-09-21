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

# Stop and disable services
systemctl stop quiz-backend.service || true
systemctl disable quiz-backend.service || true
systemctl stop webhook.service || true
systemctl disable webhook.service || true

# Remove user, group, installed packages, application files, services and configurations
sudo userdel quiz
sudo apt purge -y apache2 libapache2-mod-php php git webhook sudo
rm -r /etc/apache2/
rm -r /opt/quiz/
rm -r /etc/systemd/system/quiz-backend.service
rm -r /etc/webhook/
rm -r /etc/systemd/system/webhook.service
rm -r /etc/sudoers.d/

# Log end time
echo "Deinstallation abgeschlossen um $(date +"%d.%m.%Y %H:%M:%S")"