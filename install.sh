#!/usr/bin/env bash
set -euo pipefail

repo="egigoka/opencode"
install_dir="${OPENCODE_INSTALL_DIR:-${XDG_BIN_DIR:-$HOME/.local/bin}}"
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t opencode-install)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'opencode install: %s\n' "$1" >&2
  exit 1
}

command -v curl >/dev/null 2>&1 || fail "curl is required"

case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  MINGW* | MSYS* | CYGWIN*) os=windows ;;
  *) fail "unsupported operating system: $(uname -s)" ;;
esac

case "$(uname -m)" in
  arm64 | aarch64) arch=arm64 ;;
  x86_64 | amd64) arch=x64 ;;
  *) fail "unsupported architecture: $(uname -m)" ;;
esac

if [[ "$os" == darwin && "$arch" == x64 && "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" == 1 ]]; then
  arch=arm64
fi

target="$os-$arch"
if [[ "$arch" == x64 ]]; then
  avx2=false
  if [[ "$os" == linux ]] && grep -qwi avx2 /proc/cpuinfo 2>/dev/null; then
    avx2=true
  fi
  if [[ "$os" == darwin && "$(sysctl -n hw.optional.avx2_0 2>/dev/null || true)" == 1 ]]; then
    avx2=true
  fi
  if [[ "$avx2" == false ]]; then
    target="$target-baseline"
  fi
fi

if [[ "$os" == linux ]]; then
  musl=false
  if [[ -f /etc/alpine-release ]] || (command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl); then
    musl=true
  fi
  if [[ "$musl" == true ]]; then
    target="$target-musl"
  fi
fi

if [[ "$os" == linux ]]; then
  extension=tar.gz
  command -v tar >/dev/null 2>&1 || fail "tar is required"
else
  extension=zip
  command -v unzip >/dev/null 2>&1 || fail "unzip is required"
fi

archive="opencode-$target.$extension"
base_url="https://github.com/$repo/releases/latest/download"
printf 'Downloading %s\n' "$archive"
curl -fsSL --retry 3 "$base_url/$archive" -o "$tmp/$archive" || fail "release asset not found: $archive"
curl -fsSL --retry 3 "$base_url/SHA256SUMS" -o "$tmp/SHA256SUMS" || fail "release checksums not found"

expected=$(awk -v file="$archive" '$2 == file || $2 == "./" file { print $1; exit }' "$tmp/SHA256SUMS")
[[ -n "$expected" ]] || fail "checksum missing for $archive"
if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$tmp/$archive" | awk '{ print $1 }')
elif command -v shasum >/dev/null 2>&1; then
  actual=$(shasum -a 256 "$tmp/$archive" | awk '{ print $1 }')
else
  fail "sha256sum or shasum is required"
fi
[[ "$actual" == "$expected" ]] || fail "checksum verification failed"

if [[ "$os" == linux ]]; then
  tar -xzf "$tmp/$archive" -C "$tmp"
  binary=opencode
else
  unzip -q "$tmp/$archive" -d "$tmp"
  binary=$([[ "$os" == windows ]] && printf 'opencode.exe' || printf 'opencode')
fi

[[ -f "$tmp/$binary" ]] || fail "archive does not contain $binary"
mkdir -p "$install_dir"
cp "$tmp/$binary" "$install_dir/$binary.tmp.$$"
chmod 755 "$install_dir/$binary.tmp.$$"
mv "$install_dir/$binary.tmp.$$" "$install_dir/$binary"

printf 'Installed %s\n' "$install_dir/$binary"
if [[ ":$PATH:" != *":$install_dir:"* ]]; then
  printf "Add %s to PATH:\n  export PATH=\"%s:\$PATH\"\n" "$install_dir" "$install_dir"
fi
