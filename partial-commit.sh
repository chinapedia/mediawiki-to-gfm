SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`
VERSIONPATH="$SCRIPTPATH/VERSION"
VERSION=`cat $VERSIONPATH | head -n1`

filename=`ps aux|grep "convert\.php --"|awk '{print $13}'|awk -F'/' '{print $2}'`
[[ -z "$filename" ]] && {
    echo "Process not found"
    exit 1
}

if [ "$1" == "en" ]; then
    for x in {A..Z}; do mv Page/$x*md Page."$x"; done 
fi

git commit -am "Partially convert from $VERSION stream$filename"
git pull
git rebase
git push

