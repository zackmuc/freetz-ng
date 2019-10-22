#!/bin/bash
# generates make/libs/README.md
MYPWD="$(dirname $(realpath $0))"

echo '[//]: # ( Do not edit this file! Run generate.sh to create it. )' > "$MYPWD/README.md"
echo "### Libraries" >> "$MYPWD/README.md"

for dir in $(find "$MYPWD" -maxdepth 1 -mindepth 1 -type d | sort); do
lib="${dir##*/}"

dsc="$(sed -rn 's/[ \t]*bool "(.*)"[ \t]*/\1/p' "$MYPWD/$lib/Config.in" 2>/dev/null | head -n1)"
[ -z "$dsc" ] && dsc="$lib" && echo "ignored: $lib" 1>&2
[ "$dsc" != "$(echo "$dsc" | sed "s/^$lib//I")" ] && itm="$dsc" || itm="$lib: $dsc"
echo -e "\n  * **<u>$itm</u><a id='${lib%-cgi}'></a>**<br>"

L="$(grep -P '^[ \t]*help[ \t]*$' -nm1 "$MYPWD/$lib/Config.in" 2>/dev/null | sed 's/:.*//')"
C="$(wc -l "$MYPWD/$lib/Config.in" 2>/dev/null  | sed 's/ .*//')"
[ -z "$L" -o -z "$C" ] && echo "nohelp1: $lib" 1>&2 && continue
T=$(( $C - $L))
N="$(tail -n "$T" "$MYPWD/$lib/Config.in" | grep -P "^[ \t]*(#|(end)*if|config|bool|string|int|depends on|(end)*menu|comment|menuconfig|(end)*choice|prompt|select|default|source|help)" -n | head -n1 | sed 's/:.*//')"
help="$(tail -n "$T" "$MYPWD/$lib/Config.in" | head -n "$(( $N - 1 ))" | grep -vP '^[ \t]*$' | sed 's/[ \t]*$//g;s/^[ \t]*//g;s/$/ /g' | tr -d '\n' | sed 's/ $//')"
[ -z "$help" ] && echo "nohelp2: $lib" 1>&2 && continue
echo "    $help"

done >> "$MYPWD/README.md"

