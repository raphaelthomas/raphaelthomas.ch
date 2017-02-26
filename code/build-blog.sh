REPO_URL="https://github.com/raphaelthomas/raphaelthomas.ch.git"
REPO_DIR="/tmp/raphaelthomas.ch"
PROD_DIR="/var/www/ch.raphaelthomas"
DEV_DIR="/var/www/ch.raphaelthomas.dev"
COMMIT_LOG="$REPO_DIR/_includes/commit"
GIT="git --git-dir=$REPO_DIR/.git --work-tree=$REPO_DIR"

force=0
flag="$1"

case $flag in
    -f|--force)
        force=1
    ;;
    *)
        # nothing to do
    ;;
esac

if [ ! -d "$REPO_DIR" ]; then
    mkdir -p $REPO_DIR
    git clone $REPO_URL $REPO_DIR
fi

$GIT remote update
$GIT checkout develop

LOCAL=$($GIT rev-parse @)
REMOTE=$($GIT rev-parse @{u})

if [[ "$force" -eq "0" && $LOCAL = $REMOTE ]]; then
    echo "Nothing to do for DEV"
else
    $GIT pull origin develop
    $GIT rev-parse HEAD | tr -d '\n' > $COMMIT_LOG
    jekyll build --source $REPO_DIR --destination $DEV_DIR --config "$REPO_DIR/_config.yml,$REPO_DIR/_config-dev.yml"
    rm $COMMIT_LOG
fi

$GIT checkout master

LOCAL=$($GIT rev-parse @)
REMOTE=$($GIT rev-parse @{u})

if [[ "$force" -eq "0" && $LOCAL = $REMOTE ]]; then
    echo "Nothing to do for PROD"
else
    $GIT pull origin master
    $GIT rev-parse HEAD | tr -d '\n' > $COMMIT_LOG
    jekyll build --source $REPO_DIR --destination $PROD_DIR --config "$REPO_DIR/_config.yml,$REPO_DIR/_config-prod.yml"
    rm $COMMIT_LOG
fi
