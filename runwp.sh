VERSION=`cat VERSION | head -n1`
DATADIR=enwiki
command -v jq >/dev/null 2>&1 || { apt install jq; }
wget https://dumps.wikimedia.org/enwiki/$VERSION/dumpstatus.json -O enwiki.dumpstatus.json
if [ $1 = "-c" ]; then
    echo "Continue..."
else
    if [ $1 = "-r" ]; then
        echo "Start over and reusing data..."
    else
        echo "Start over..."
        rm -rv $DATADIR
    fi
fi
mkdir $DATADIR
cat enwiki.dumpstatus.json | jq ".jobs.articlesdump.files[].url" | awk -F '"' '{print "https://dumps.wikimedia.org" $2 }' > enwiki/$VERSION.sh

LOG=$DATADIR.convert.log
REPO=../wikipedia.en
if [ -d $REPO ]; then
    echo "$REPO exists"
else
    cd ..
    git clone git@github.com:chinapedia/wikipedia.en.git --depth=3
    cd -
fi

> $LOG

counter=0
for url in $(cat $DATADIR/$VERSION.sh); do
    counter=$((counter + 1))
    echo "Start "$url >> $LOG
    cd $DATADIR

    if [ -f $counter ]; then
        echo "stream " $counter " exists."
        if [ $1 = "-c" ]; then
            cd ..
            continue
        fi
    else 
        wget $url -O $counter.bz2
        bzip2 -dk $counter.bz2
    fi
    cd ..

        php convert.php --filename="$DATADIR"/"$counter" --output="$REPO" --luafilter=filters/gfm-en.lua --template=cfm-en
        cd $REPO
        git pull
        for x in {A..Z}; do mv Page/$x*md Page."$x"; done        
        git add .
        git commit -m "Convert from $VERSION stream$counter"
        git push
        cd -
        echo "Done stream "$counter >> $LOG

done

