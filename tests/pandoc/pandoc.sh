title="2020年"
curl "https://zh.wikipedia.org/w/api.php?action=query&prop=revisions&rvprop=content&format=json&titles=2020年&rvslots=main" | jq ".query.pages[].revisions[].slots.main" > 2020y.json
cat 2020y.json | jq -r ".[]" | sed -e '1,2d' > 2020y.mediawiki
pandoc --data-dir=app --template=cfm-zh -V "cfmtitle=2020年" -V "cfmurl=2020年" -f mediawiki -t gfm 2020y.mediawiki --lua-filter=filters/gfm-zh.lua > ../wikipedia.zh/Page/$title.md


for i in 'clr'
do
    pandoc -f mediawiki -t gfm $i.mediawiki --lua-filter=../../filters/gfm-en.lua > $i.md
done

for i in '1' '2' '3'
do
    pandoc -f mediawiki -t gfm $i.mediawiki --lua-filter=../../filters/gfm-zh.lua > $i.md
done

