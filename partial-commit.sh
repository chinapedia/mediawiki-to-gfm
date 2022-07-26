SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`
VERSIONPATH="$SCRIPTPATH/VERSION"
VERSION=`cat $VERSIONPATH | head -n1`

filename=`ps aux|grep "convert.php"|awk '{print $15}'|awk -F'/' '{print $2}'`
[[ -z "$filename" ]] && {
    echo "Process not found"
    exit 1
}

if [ "$1" == "en" ]; then
    for x in {A..Z}; do mv Page/$x*md Page."$x"; done 
fi

find Errors -name "*.log" -type f -size -1c -delete
git add Errors
git add Page
git commit -am "Partially convert from $VERSION stream$filename"
#git pull
#git rebase
git push

