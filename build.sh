#!/bin/sh

set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
package="$root/packages/opencode"
platform=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)

case "$arch" in
  aarch64) arch=arm64 ;;
  x86_64) arch=x64 ;;
esac

bun run --cwd "$package" build --single "$@"

source="$package/dist/opencode-$platform-$arch/bin/opencode"
target="$HOME/.local/bin/opencode-dev"

if [ ! -f "$source" ]; then
  printf 'Built binary not found: %s\n' "$source" >&2
  exit 1
fi

mkdir -p "$(dirname -- "$target")"
cp "$source" "$target"
chmod +x "$target"

printf 'Installed %s\n' "$target"
