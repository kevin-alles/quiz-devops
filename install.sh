#! /bin/bash

set -e

# Set log file location
LOG_FILE=/tmp/install.log

# Truncate log file at start
: > "$LOG_FILE"

# Redirect all output (stdout and stderr) to log file and console
exec > >(tee -a $LOG_FILE) 2>&1

# Log start time
echo "Installation gestartet um $(date +"%d.%m.%Y %H:%M:%S")"

# Install necessary packages
echo "Installing necessary packages..."
apt-get update
apt-get install -y git apache2 php libapache2-mod-php

# Variables
APPDIR="/opt/quiz"
APACHE2CONF="quiz.conf"
SYSTEMDBACKENDSERVICE="quiz-backend.service"
USER="quiz"
GROUP="quiz"

# Create user and group if they don't exist
if ! id -u $USER &>/dev/null; then
    echo "Creating user and group '$USER'..."
    groupadd --system $GROUP
    useradd --system --gid $GROUP --home $APPDIR --shell /sbin/nologin $USER
else
    echo "User '$USER' already exists."
    usermod -d $APPDIR $USER
    usermod -s /sbin/nologin $USER
fi

# Create application directory
echo "Creating application directory..."
mkdir -p $APPDIR

# Create application subdirectories
echo "Creating application subdirectories..."
for dir in devops frontend backend; do
    mkdir -p "$APPDIR/$dir"
    chown $USER:$GROUP "$APPDIR/$dir"
    chmod 750 "$APPDIR/$dir"
done

# Start deployment of repositories
echo "Deploying repositories..."
bash $APPDIR/devops/redeploy.sh main all

# Enable and start Apache2
echo "Enabling and starting Apache2..."
a2dissite 000-default.conf
rm /etc/apache2/sites-enabled/000-default.conf
ln -sf $APPDIR/devops/$APACHE2CONF /etc/apache2/sites-available/$APACHE2CONF
a2ensite $APACHE2CONF
a2enmod rewrite
systemctl enable apache2
systemctl restart apache2

# Set up systemd service
echo "Setting up systemd service..."
ln -sf $APPDIR/devops/$SYSTEMDBACKENDSERVICE /etc/systemd/system/
systemctl daemon-reload
systemctl --user enable $SYSTEMDBACKENDSERVICE
systemctl --user start $SYSTEMDBACKENDSERVICE
systemctl --user status $SYSTEMDBACKENDSERVICE

# Set up sudoers for $USER user
echo "Setting up sudoers for $USER user..."
echo "$USER ALL=NOPASSWD: /bin/systemctl restart $SYSTEMDBACKENDSERVICE, /bin/systemctl status $SYSTEMDBACKENDSERVICE, /bin/systemctl restart $APACHE2CONF" > /etc/sudoers.d/$USER
chmod 440 /etc/sudoers.d/$USER

# Set permissions
echo "Setting permissions..."
chown -R $USER:$GROUP $APPDIR
chmod 750 $APPDIR

# Start redeploy script for all repositories
echo "Starting redeploy script for all repositories..."
bash $APPDIR/devops/redeploy.sh main all &

# Log end time
echo "Installation finished at $(date +"%d.%m.%Y %H:%M:%S")"