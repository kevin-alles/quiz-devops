#! /bin/bash

set -e

# Set log file location
LOG_FILE=/opt/quiz/devops/redeploy.log

# Truncate log file at start
: > "$LOG_FILE"

# Redirect all output (stdout and stderr) to log file and console
exec > >(tee -a $LOG_FILE) 2>&1

# Log start time
echo "Redeploy started at $(date '+%Y-%m-%d %H:%M:%S')"

BRANCH="${1:-main}"
REPO_NAME="${2:-all}"

# If REPO_NAME is 'all', process all repositories
if [[ "$REPO_NAME" == "all" ]]; then
    # Process all repositories: devops, frontend, backend
    echo "Processing all repositories..."
    exit_codes=()
    overall_exit_code=0
    BRANCH="main"  # Ensure branch is main when deploying all
    
    for part in devops frontend backend; do
        echo "Now processing $part..."
        bash "$0" "$BRANCH" "$part"
        exit_code=$?
        exit_codes+=("$part:$exit_code")
        
        if [[ $exit_code -ne 0 ]]; then
            overall_exit_code=1
        fi
    done
    
    echo "Exit codes summary:"
    for result in "${exit_codes[@]}"; do
        echo "  $result"
    done
    
    exit $overall_exit_code
fi
    
# Extract repository part from git URL using regex
if [[ "$REPO_NAME" =~ git://github.com/kevin-alles//quiz-(.+)\.git ]]; then
    REPO_NAME="${BASH_REMATCH[1]}"
fi

REPO_URL="https://github.com/kevin-alles/quiz-${REPO_NAME}.git"

APPDIR="/opt/quiz"
REPODIR="$APPDIR/$REPO_NAME"
WORKDIR="$APPDIR/devops"
REDEPLOY_DIR="$WORKDIR/redeploy/$REPO_NAME"
REPO_TAG="latest"
JAR_NAME="Quiz-Backend-0.0.1-SNAPSHOT.jar"
SYSTEMDBACKENDSERVICE="quiz-backend.service"
SYSTEMDWEBHOOKSERVICE="webhook.service"

# Robustly extract branch name from possible formats
if [[ "$BRANCH" =~ ^refs/heads/ ]]; then
    BRANCH_NAME="${BRANCH#refs/heads/}"
elif [[ "$BRANCH" =~ ^origin/ ]]; then
    BRANCH_NAME="${BRANCH#origin/}"
else
    BRANCH_NAME="$BRANCH"
fi

# Ensure redeploy directory exists and is empty
echo "Clearing $REDEPLOY_DIR"
rm -rf "$REDEPLOY_DIR"
if ! mkdir -p "$REDEPLOY_DIR"; then
    echo "ERROR: Failed to create $REDEPLOY_DIR at $(date '+%Y-%m-%d %H:%M:%S')"
    exit 1
fi

# fill redeploy directory
echo "Preparing redeploy directory $REDEPLOY_DIR"
if [[ "$REPO_NAME" == "backend" ]]; then
    # Download Release into redeploy directory
    echo "Downloading release from $REPO_URL with Tag $REPO_TAG"
    # TODO: Make dynamic again
    wget -q -O- "https://github.com/kevin-alles/quiz-backend/releases/download/latest/$JAR_NAME" > "$REDEPLOY_DIR/quiz-backend.jar"
else
    # Clone repository into redeploy directory
    echo "Cloning repository from $REPO_URL (branch: $BRANCH_NAME) to $REDEPLOY_DIR"
    if ! git clone --depth 1 --branch "$BRANCH_NAME" "$REPO_URL" "$REDEPLOY_DIR"; then
        echo "ERROR: Failed to clone repository at $(date '+%Y-%m-%d %H:%M:%S')"
        exit 1
    fi
fi

# process "devops" repository
if [[ "$REPO_NAME" == "devops" ]]; then
    # Check if redeploy.sh changed and update if necessary
    echo "Checking for changes in redeploy.sh"
    if ! cmp -s "$REDEPLOY_DIR/redeploy.sh" "$WORKDIR/redeploy.sh"; then
        echo "redeploy.sh has changed, updating and restarting"
        if ! cp "$REDEPLOY_DIR/redeploy.sh" "$WORKDIR/redeploy.sh"; then
            echo "ERROR: Failed to update redeploy.sh at $(date '+%Y-%m-%d %H:%M:%S')"
            exit 1
        fi
        bash "$WORKDIR/redeploy.sh" "$BRANCH_NAME" "$REPO_NAME" &
        exit 0
    else
        echo "redeploy.sh has not changed, continuing with redeployment"
    fi

    # Copy updated service files and reload systemd
    echo "Updating service files and reloading systemd"
    cp $REDEPLOY_DIR/* $WORKDIR/
    systemctl daemon-reload
    systemctl restart $SYSTEMDWEBHOOKSERVICE

elif [[ "$REPO_NAME" == "frontend" ]]; then
    # move everything from redeploy to production
    cp $REDEPLOY_DIR/* $REPODIR/
    systemctl restart apache2

elif [[ "$REPO_NAME" == "backend" ]]; then
    # move jar-file from redeploy to production
    cp $REDEPLOY_DIR/quiz-backend.jar $REPODIR/quiz-backend.jar
    cp $WORKDIR/start.sh $REPODIR/
    systemctl restart $SYSTEMDBACKENDSERVICE

fi

# Delete temporary redeploy folder
echo "Deleteing $REDEPLOY_DIR"
if ! rm -rf "$REDEPLOY_DIR"; then
    echo "ERROR: Failed to delete $REDEPLOY_DIR at $(date '+%Y-%m-%d %H:%M:%S')"
    exit 1
fi

echo "Redeploy finished at $(date '+%Y-%m-%d %H:%M:%S')"
