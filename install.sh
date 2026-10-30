#!/bin/sh
# usage: curl -fsSL https://raw.githubusercontent.com/Ubikron-Tech-Farm/mimic-cli/main/install.sh | sh   (env: MIMIC_VERSION, MIMIC_INSTALL_DIR, MIMIC_RELEASE_REPO, GH_TOKEN)
set -eu

repo="${MIMIC_RELEASE_REPO:-Ubikron-Tech-Farm/mimic-cli}"
token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

fail() {
	printf 'mimic install: %s\n' "$1" >&2
	exit 1
}

need() {
	command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

need curl
need tar
need uname

case "$(uname -s)" in
	Darwin) os=darwin ;;
	Linux) os=linux ;;
	*) fail "unsupported OS $(uname -s); download a release manually from https://github.com/$repo/releases" ;;
esac

case "$(uname -m)" in
	x86_64 | amd64) arch=amd64 ;;
	arm64 | aarch64) arch=arm64 ;;
	*) fail "unsupported architecture $(uname -m)" ;;
esac

api() {
	if [ -n "$token" ]; then
		curl -fsSL -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$repo/$1"
	else
		curl -fsSL -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$repo/$1"
	fi
}

if [ -n "${MIMIC_VERSION:-}" ]; then
	tag="v${MIMIC_VERSION#v}"
	release="$(api "releases/tags/$tag")" || fail "release $tag not found (private repo? set GH_TOKEN)"
else
	release="$(api releases/latest)" || fail "could not find the latest release (private repo? set GH_TOKEN)"
	tag="$(printf '%s\n' "$release" | sed -n 's/^ *"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)"
fi
[ -n "$tag" ] || fail "could not determine the release tag"
version="${tag#v}"
archive="mimic-cli_${version}_${os}_${arch}.tar.gz"

asset_url() {
	printf '%s\n' "$release" | awk -v name="$1" '
		/"url": *"https:\/\/api\.github\.com\/repos\/.*\/releases\/assets\/[0-9]+"/ { url = $0; sub(/.*"url": *"/, "", url); sub(/".*/, "", url) }
		$0 ~ "\"name\": *\"" name "\"" { print url; exit }
	'
}

download() {
	url="$(asset_url "$1")"
	[ -n "$url" ] || fail "release $tag has no asset $1"
	if [ -n "$token" ]; then
		curl -fsSL -H "Authorization: Bearer $token" -H "Accept: application/octet-stream" -o "$2" "$url"
	else
		curl -fsSL -H "Accept: application/octet-stream" -o "$2" "$url"
	fi
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

printf 'Downloading mimic %s for %s/%s...\n' "$version" "$os" "$arch"
download "$archive" "$work/$archive"
download checksums.txt "$work/checksums.txt"

expected="$(awk -v name="$archive" '$2 == name { print $1 }' "$work/checksums.txt")"
[ -n "$expected" ] || fail "checksums.txt has no entry for $archive"
if command -v sha256sum >/dev/null 2>&1; then
	actual="$(sha256sum "$work/$archive" | awk '{ print $1 }')"
elif command -v shasum >/dev/null 2>&1; then
	actual="$(shasum -a 256 "$work/$archive" | awk '{ print $1 }')"
else
	fail "sha256sum or shasum is required to verify the download"
fi
[ "$expected" = "$actual" ] || fail "checksum mismatch for $archive"

tar -xzf "$work/$archive" -C "$work" mimic

if [ -n "${MIMIC_INSTALL_DIR:-}" ]; then
	dir="$MIMIC_INSTALL_DIR"
elif [ -w /usr/local/bin ]; then
	dir=/usr/local/bin
else
	dir="$HOME/.local/bin"
fi
mkdir -p "$dir"
install -m 0755 "$work/mimic" "$dir/mimic"

printf 'Installed mimic %s to %s/mimic\n' "$version" "$dir"
case ":$PATH:" in
	*":$dir:"*) ;;
	*) printf 'Add %s to your PATH, e.g. echo '\''export PATH="%s:$PATH"'\'' >> ~/.profile\n' "$dir" "$dir" ;;
esac
printf 'Next: mimic login   (or: mimic login --server your-host/mimic)\n'
