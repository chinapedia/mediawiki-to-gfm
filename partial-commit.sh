SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`
VERSIONPATH="$SCRIPTPATH/VERSION"
VERSION=`cat $VERSIONPATH | head -n1`

filename=`ps aux|grep "convert.php"|awk '{print $15}'|awk -F'/' '{print $2}'`
filename=${filename##[[:space:]]}
[[ -z "$filename" ]] && {
    echo "Process not found"
    exit 1
}

find Errors -name "*.log" -type f -size -1c -delete
rm Errors/*.wikitext
git add Errors/*.err.log
git add Page
git add Redirect
git commit -am "Partially convert from $VERSION stream$filename"
git push

