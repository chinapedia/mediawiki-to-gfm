LOG=convert-to-plain.log
> $LOG 

counter=1
for filename in data/*.xml*; do
    echo "Start "$filename >> $LOG 
    php convert.php --filename="$filename" --format=plain --output=/srv/20190501.plain."$counter" 
    echo "Done "$filename >> $LOG
    counter=$((counter + 1))
done
exit

echo "Unzip bz2..." >> $LOG
mkdir data 
cat dumpstatus.json | jq ".jobs.articlesdump.files[].url" | awk -F '"' '{print "wget https://dumps.wikimedia.org" $2 }' > data/20190501.sh
cd data
bash -x 20190501.sh
for filename in *.bz2; do
    bzip2 -dk $filename
    mv $filename /tmp/
done
cd ..
for filename in data/*.xml*; do
    echo $filename
done

