export WIKILANG=$1
if [ $1 = "-c" ]; then
    export WIKILANG=$2
fi

if [ $1 = "-r" ]; then
    export WIKILANG=$2
fi

if [ -z $WIKILANG ]; then
    export WIKILANG=zh
fi

day=$(date +%d)
VERSION=`date '+%Y%m01'`
if [ "$day" -gt "23" ]; then
    VERSION=`date '+%Y%m20'`
fi
echo $VERSION > VERSION

DATADIR=$WIKILANG"wiki"
FILTER="filters/gfm-cjk.lua"
if [ -f $FILTER ]; then 
    echo "Filter "$FILTER" exists... Version: $VERSION"
else
    echo "Filter "$FILTER" does not exist, exit..."
    exit 1
fi

command -v jq >/dev/null 2>&1 || { apt install jq; }
wget https://dumps.wikimedia.org/$DATADIR/$VERSION/dumpstatus.json -O $DATADIR.dumpstatus.json
if [ $1 = "-c" ]; then
    echo "Continue $WIKILANG..."
else
    if [ $1 = "-r" ]; then
        echo "Start over and reusing data..."
    else
        echo "Start over $WIKILANG..."
        rm -rv $DATADIR
    fi
fi
mkdir $DATADIR
cat $DATADIR.dumpstatus.json | jq ".jobs.articlesdump.files[].url" | sort | awk -F '"' '{print "https://dumps.wikimedia.org" $2 }' > $DATADIR/$VERSION.sh

LOG=$DATADIR.convert.log
REPO="../wikipedia."$WIKILANG
if [ -d $REPO ]; then
    echo "$REPO exists"
else
    cd ..
    git clone git@github.com:chinapedia/wikipedia.$WIKILANG.git --depth=3
    cd -
fi
 
> $LOG 

counter=1
for url in $(cat $DATADIR/$VERSION.sh); do
    echo "Start "$url >> $LOG
    cd $DATADIR

    if [ -f $counter ]; then
        echo "stream " $counter " exists."
        if [ $1 = "-c" ]; then
            cd ..
            counter=$((counter + 1))
            continue
        fi
    else 
        wget $url -O $counter.bz2
        bzip2 -dk $counter.bz2
    fi
    cd ..
        mkdir "$REPO/Errors"
        mkdir "$REPO/Redirect"
        php -d memory_limit=4096M convert.php --filename="$DATADIR"/"$counter" --output="$REPO" --luafilter="$FILTER" --template=cfm-"$WIKILANG"
        cd $REPO
        rm Errors/*.wikitext
        find Errors -name "*.log" -type f -size -1c -delete
        git add .
        git commit -m "Convert from $VERSION stream$counter"
        git push
        cd -
        echo "Done stream "$counter >> $LOG

    counter=$((counter + 1))
done

cd $REPO
sed -i .bak -E "s/[0-9]{8}/20220801/g" README.md
git add README.md
rm README.md.bak
git commit -m "Set version to $VERSION"
git push

