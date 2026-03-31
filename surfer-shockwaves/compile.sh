#!/bin/bash
set -e

cargo build --target wasm32-unknown-unknown

WASM="target/wasm32-unknown-unknown/debug/surfer_shockwaves.wasm"

# optionally:
if [ "$1" = "linux" ]; then
  cp $WASM ~/.local/share/surfer/translators/
  echo "copied to Linux folder"
fi
if [ "$1" = "windows" ]; then
  cp $WASM ~/AppData/Roaming/surfer-project/surfer/data/translators
  echo "copied to Windows folder"
fi
if [ "$1" = "here" ]; then
  cp $WASM .
  echo "copied to this folder"
fi

echo "[DONE]"
# sleep 5
