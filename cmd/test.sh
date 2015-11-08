#! /bin/sh
rm -rf ./public/*
hexo g
cp -r ./private/* ./public
hexo s
