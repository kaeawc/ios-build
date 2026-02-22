#!/usr/bin/env bash

SHFMT_VERSION="3.10.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect operating system
detect_os() {
  case "$(uname -s)" in
    Darwin*)
      echo "macos"
      ;;
    Linux*)
      echo "linux"
      ;;
    CYGWIN* | MINGW* | MSYS*)
      echo "windows"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Detect architecture
detect_arch() {
  case "$(uname -m)" in
    x86_64 | amd64)
      echo "amd64"
      ;;
    arm64 | aarch64)
      echo "arm64"
      ;;
    armv7l)
      echo "arm"
      ;;
    i386 | i686)
      echo "386"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_macos() {
  echo -e "${YELLOW}Installing shfmt on macOS...${NC}"
  if command_exists brew; then
    echo -e "${GREEN}Using Homebrew to install shfmt${NC}"
    brew install shfmt
    return $?
  else
    echo -e "${YELLOW}Homebrew not found. Falling back to binary installation...${NC}"
    install_binary "darwin"
    return $?
  fi
}

install_linux() {
  echo -e "${YELLOW}Installing shfmt on Linux...${NC}"
  install_binary "linux"
  return $?
}

install_binary() {
  local os="$1"
  local arch
  arch=$(detect_arch)

  echo -e "${YELLOW}Installing shfmt binary for $os ($arch)...${NC}"

  if [[ "$arch" == "unknown" ]]; then
    echo -e "${RED}Unsupported architecture: $(uname -m)${NC}"
    return 1
  fi

  install_dir="$HOME/.local/bin"
  mkdir -p "$install_dir"

  local binary_name="shfmt_v${SHFMT_VERSION}_${os}_${arch}"
  local download_url="https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/${binary_name}"
  local target_file="$install_dir/shfmt"

  echo -e "${GREEN}Downloading shfmt from GitHub releases...${NC}"

  if command_exists curl; then
    curl -L -o "$target_file" "$download_url"
  elif command_exists wget; then
    wget -O "$target_file" "$download_url"
  else
    echo -e "${RED}Neither curl nor wget found.${NC}"
    return 1
  fi

  if [[ ! -f "$target_file" ]]; then
    echo -e "${RED}Failed to download shfmt binary${NC}"
    return 1
  fi

  chmod +x "$target_file"
  echo -e "${GREEN}shfmt installed to $install_dir${NC}"

  if [[ ":$PATH:" != *":$install_dir:"* ]]; then
    echo -e "${YELLOW}Add $install_dir to your PATH:${NC}"
    echo "export PATH=\"\$PATH:$install_dir\""
  fi

  return 0
}

verify_installation() {
  if command_exists shfmt; then
    echo -e "${GREEN}shfmt is installed and available${NC}"
    shfmt --version 2>/dev/null || true
    return 0
  else
    echo -e "${RED}shfmt is not available in PATH${NC}"
    return 1
  fi
}

main() {
  echo -e "${GREEN}shfmt Installation Script${NC}"
  echo -e "${GREEN}=========================${NC}"

  local os
  os=$(detect_os)
  echo -e "${YELLOW}Detected OS: $os${NC}"

  local install_result=0
  case $os in
    macos)
      install_macos || install_result=$?
      ;;
    linux)
      install_linux || install_result=$?
      ;;
    *)
      echo -e "${RED}Unsupported operating system: $os${NC}"
      exit 1
      ;;
  esac

  if [[ $install_result -eq 0 ]]; then
    echo -e "${GREEN}Installation completed successfully!${NC}"
    verify_installation
  else
    echo -e "${RED}Installation failed!${NC}"
    exit 1
  fi
}

main "$@"
