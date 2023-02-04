#!/usr/bin/env bash
URL="$1"
IMAGE_CACHE="$2"
FILENAME="$3"

if [ ! -d "$IMAGE_CACHE" ]; then
  mkdir -p "$IMAGE_CACHE"
fi

if [ -e "$IMAGE_CACHE/$FILENAME" ]
then
  echo "Image already downloaded."
  exit 0
fi

echo "Downloading Image"

wget "$URL" -qO- | unxz > "$IMAGE_CACHE/$FILENAME"

ls "$IMAGE_CACHE"
stat "$IMAGE_CACHE/$FILENAME"
