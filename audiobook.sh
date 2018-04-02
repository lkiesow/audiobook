#!/bin/sh

set -o nounset
set -o errexit

suggested_title="$(basename "$1" | sed 's/\.[^.]*$//')"

read -r -p 'Artist: ' artist
read -r -p "Title [${suggested_title}]: " title
read -r -p "Genre [Audiobook]: " genre

if [ -z "${title}" ]; then
	title="${suggested_title}"
fi
if [ -z "${genre}" ]; then
	title="Audiobook"
fi

output="${2:-}"
if [ -z "${output}" ]; then
	output="${artist} - ${title}.mp3"
fi

# autocrop
crop="$(ffprobe -f lavfi -hide_banner -i "movie='$1',cropdetect=round=2[out0]" 2>&1 |\
	sed -n 's/^\[Parsed_cropdetect_1.* \(crop=.*\)$/\1/p' | head -n1)"

# loudnorm
measures="$(ffprobe -f lavfi -hide_banner -i "amovie=$1,loudnorm=print_format=json[out]" 2>&1 |\
	sed -n '/Parsed_loudnorm_1/{:a;n;p;ba}')"

input_i="$(echo "$measures" | jq -r .input_i)"
input_tp=$(echo "$measures" | jq -r .input_tp)
input_lra=$(echo "$measures" | jq -r .input_lra)
input_thresh=$(echo "$measures" | jq -r .input_thresh)

measured="measured_i=${input_i}:measured_tp=${input_tp}:measured_lra=${input_lra}:measured_thresh=${input_thresh}"

set -o xtrace
ffmpeg -i "$1" -vframes 1 \
	-map 0:a -filter:a loudnorm=I=-16:lra=1:tp=-1:${measured} \
	-c:a libmp3lame -ac 1 -b:a 96k \
	-map 0:v -c:v png -filter:v "${crop}" \
	-id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (Front)" \
	-metadata "title=${title}" \
	-metadata "artist=${artist}" \
	-metadata "genre=${genre}" \
	"${output}"
