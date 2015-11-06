#! /bin/sh
hexo g
hexo d
rsync -r --delete -v public/* root@chunqi.li:/var/www/html/
