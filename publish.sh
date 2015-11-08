#! /bin/sh
rm -rf ./public/*
hexo g
hexo d
rsync -r --delete -v public/* root@chunqi.li:/var/www/html/
