REPO_URL="https://github.com/raphaelthomas/raphaelthomas.ch.git"
REPO_DIR="/tmp/raphaelthomas.ch"
PROD_DIR="/var/www/ch.raphaelthomas"
COMMIT_LOG="$REPO_DIR/commit"
GIT="git --git-dir=$REPO_DIR/.git --work-tree=$REPO_DIR"
LOC_TMP="/tmp/ch.raphaelthomas-location.json"

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
    git clone --recurse-submodules $REPO_URL $REPO_DIR
    force=1
fi

$GIT remote update
$GIT checkout master

LOCAL=$($GIT rev-parse @)
REMOTE=$($GIT rev-parse @{u})

if [[ "$force" -eq "0" && $LOCAL = $REMOTE ]]; then
    echo "Nothing to do for PROD"
else
    if [ ! -d "$PROD_DIR" ]; then
        mkdir -p $PROD_DIR
    fi
    $GIT pull origin master
    $GIT rev-parse HEAD | tr -d '\n' > $COMMIT_LOG
    hugo --config "$REPO_DIR/config.toml" --source $REPO_DIR --destination $PROD_DIR
    if [ -f "$LOC_TMP" ]; then
        cp $LOC_TMP "$PROD_DIR/location.json"
    fi
    rm $COMMIT_LOG
fi
