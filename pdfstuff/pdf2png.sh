#!/usr/bin/env bash

for i in 0 1 2 3 4 5 ; do
    convert -density 300 "crap.pdf[$i]" -quality 100 $i.png
done
