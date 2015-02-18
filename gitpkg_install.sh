#!/bin/bash

gitid=$1
pkg=$(basename $1)
dst=$2

wget "https://github.com/${gitid}/archive/master.tar.gz" -O "${dst}/${pkg}.tar.gz"
mkdir -p "${dst}/${pkg}"
tar zxf "${dst}/${pkg}.tar.gz" --strip 1 -C "${dst}/${pkg}"
rm "${dst}/${pkg}.tar.gz"
