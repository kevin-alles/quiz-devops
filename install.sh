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
apt-get install -y git apache2 webhook sudo php libapache2-mod-php

# Variables
APPDIR="/opt/quiz"
APACHE2CONF="quiz.conf"
SYSTEMDBACKENDSERVICE="quiz-backend.service"
SYSTEMDWEBHOOKSERVICE="webhook.service"
USER="quiz"
GROUP="quiz"

# Create user and group if they don't exist
if ! id -u $USER &>/dev/null; then
    echo "Creating user and group '$USER'..."
    sudo groupadd --system $GROUP
    sudo useradd --system --gid $GROUP --home $APPDIR --shell /sbin/nologin $USER
else
    echo "User '$USER' already exists."
    sudo usermod -d $APPDIR $USER
    sudo usermod -s /sbin/nologin $USER
fi

# Create application directory
echo "Creating application directory..."
sudo mkdir -p $APPDIR

# Create application subdirectories
echo "Creating application subdirectories..."
for dir in devops frontend backend; do
    sudo mkdir -p "$APPDIR/$dir"
    sudo chown $USER:$GROUP "$APPDIR/$dir"
    sudo chmod 750 "$APPDIR/$dir"
done

# Start deployment of devops repository
echo "Deploying devops repository..."
git clone https://github.com/kevin-alles/quiz-devops.git "$APPDIR/devops"
sudo chmod ug+x $APPDIR/devops/*.sh

# Enable and start Apache2
echo "Enabling and starting Apache2..."
sudo a2dissite 000-default.conf
sudo rm /etc/apache2/sites-available/000-default.conf
sudo ln -sf $APPDIR/devops/$APACHE2CONF /etc/apache2/sites-available/$APACHE2CONF
sudo a2ensite $APACHE2CONF
sudo a2enmod rewrite
sudo systemctl enable apache2
sudo systemctl restart apache2

# Set up systemd service for backend
echo "Setting up systemd service for backend ..."
sudo ln -sf $APPDIR/devops/$SYSTEMDBACKENDSERVICE /etc/systemd/system/
sudo ln -sf $APPDIR/devops/start.sh $APPDIR/backend/start.sh
sudo systemctl daemon-reload
sudo systemctl enable $SYSTEMDBACKENDSERVICE
sudo systemctl start $SYSTEMDBACKENDSERVICE

# Set up webhook
echo "Setting up webhook..."
sudo mkdir -p /etc/webhook
sudo ln -sf $APPDIR/devops/hooks.yml /etc/webhook/

# Set up systemd service for webhook
echo "Setting up systemd service for webhook..."
sudo ln -sf $APPDIR/devops/$SYSTEMDWEBHOOKSERVICE /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable $SYSTEMDWEBHOOKSERVICE
sudo systemctl start $SYSTEMDWEBHOOKSERVICE

# Set up sudoers for $USER user
echo "Setting up sudoers for $USER user..."
echo "$USER ALL=NOPASSWD: /bin/systemctl restart $SYSTEMDBACKENDSERVICE, /bin/systemctl status $SYSTEMDBACKENDSERVICE, /bin/systemctl restart $APACHE2CONF, /bin/systemctl daemon-reload" | sudo tee /etc/sudoers.d/$USER
sudo chmod 440 /etc/sudoers.d/$USER

# Set permissions
echo "Setting permissions..."
sudo chown -R $USER:$GROUP $APPDIR
sudo chmod 750 $APPDIR

# Start redeploy script for all repositories
echo "Starting redeploy script for all repositories..."
sudo -u quiz bash $APPDIR/devops/redeploy.sh main all &

# Log end time
echo "Installation finished at $(date +"%d.%m.%Y %H:%M:%S")"