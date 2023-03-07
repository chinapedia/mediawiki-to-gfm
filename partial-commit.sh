SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`
VERSIONPATH="$SCRIPTPATH/VERSION"
VERSION=`cat $VERSIONPATH | head -n1`

filename=`ps aux|grep "convert.php"|awk '{print $15}'|awk -F'/' '{print $2}'`
filename=${filename##[[:space:]]}
python3 ../mediawiki-to-gfm/clean.py
[[ -z "$filename" ]] && {
    echo "Process not found"
    exit 1
}

find Errors -name "*.log" -type f -size -1c -delete
rm Errors/*.wikitext
git add Page
git commit -m "Partially convert from $VERSION stream$filename"
if [ "$1" == "en" ]; then
    python3 ../mediawiki-to-gfm/clean.py r
    git add Redirect
    git commit -m "Partially update redirects from $VERSION stream$filename"
fi
git push

