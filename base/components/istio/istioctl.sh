# istioctl_bin - echoes the path of the pinned istioctl, downloading it on
# first use into the kdrill state directory (checksum-verified; nothing is
# installed system-wide). Sourced by install.sh and courses/istio/lib.sh.
ISTIO_VERSION=1.31.4

istioctl_bin() {
  local dir="${KDRILL_STATE_DIR:-$HOME/.kdrill}/bin" os arch sum file tmp
  local bin="$dir/istioctl"
  if [[ -x "$bin" ]] && [[ "$("$bin" version --remote=false 2>/dev/null)" == *"$ISTIO_VERSION"* ]]; then
    echo "$bin"; return 0
  fi
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"; arch="$(uname -m)"
  case "$os/$arch" in
    darwin/arm64)               file=osx-arm64;   sum=2be63df4a0fedb10c9c5402cdbf2f666e84330f3c68aef244975225ea63ef675 ;;
    darwin/x86_64)              file=osx-amd64;   sum=da2398901943b3718566ca59311e045a0d99089006394fb573f34c23cd720311 ;;
    linux/x86_64)               file=linux-amd64; sum=7c00227d87f280c2450483e3518e3a73af62c057363b779ea80931c409e8852e ;;
    linux/aarch64|linux/arm64)  file=linux-arm64; sum=3a1a82af8788059192d411e92d952c32d31a69bc20a039b3915f536d395e0c24 ;;
    *) echo "unsupported platform $os/$arch for istioctl" >&2; return 1 ;;
  esac
  file="istioctl-${ISTIO_VERSION}-${file}.tar.gz"
  mkdir -p "$dir"
  tmp="$(mktemp -d "$dir/dl.XXXXXX")"
  if ! curl -fsSL -o "$tmp/$file" "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/$file"; then
    rm -rf "$tmp"; echo "could not download istioctl $ISTIO_VERSION" >&2; return 1
  fi
  if [[ "$(shasum -a 256 "$tmp/$file" 2>/dev/null || sha256sum "$tmp/$file")" != "$sum "* ]]; then
    rm -rf "$tmp"; echo "istioctl checksum mismatch" >&2; return 1
  fi
  tar xzf "$tmp/$file" -C "$tmp" istioctl && mv "$tmp/istioctl" "$bin" && chmod +x "$bin"
  rm -rf "$tmp"
  echo "$bin"
}
