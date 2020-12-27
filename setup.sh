command -v jq >/dev/null 2>&1 || {
    wget https://github.com/jgm/pandoc/releases/download/2.9.1/pandoc-2.9.1-1-amd64.deb;
    apt install ./pandoc-2.9.1-1-amd64.deb;
}

apt install php7.2-cli php7.2-xml php7.2-mbstring composer zip

composer update --no-dev

git clone https://github.com/chinapedia/pandoc-php
cp pandoc-php/src/Pandoc/* vendor/ryakad/pandoc-php/src/Pandoc/ -v
