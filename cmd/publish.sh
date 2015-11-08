#! /bin/sh
rm -rf ./public/*
hexo g
cp -r ./private/* ./public
hexo d
rsync -r --delete -v ./public/* root@chunqi.li:/var/www/html/
