#!/usr/bin/env bash

SWIFTFORMAT_VERSION="0.54.6"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

detect_os() {
  case "$(uname -s)" in
    Darwin*)
      echo "macos"
      ;;
    Linux*)
      echo "linux"
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
  echo -e "${YELLOW}Installing SwiftFormat on macOS...${NC}"
  if command_exists brew; then
    echo -e "${GREEN}Using Homebrew to install SwiftFormat${NC}"
    brew install swiftformat
    return $?
  else
    echo -e "${YELLOW}Homebrew not found. Attempting manual installation...${NC}"
    install_manual
    return $?
  fi
}

install_linux() {
  echo -e "${YELLOW}Installing SwiftFormat on Linux...${NC}"
  echo -e "${YELLOW}SwiftFormat requires manual installation on Linux...${NC}"
  install_manual
  return $?
}

install_manual() {
  echo -e "${YELLOW}Installing SwiftFormat manually...${NC}"

  install_dir="$HOME/.local/bin"
  mkdir -p "$install_dir"

  local os
  os=$(detect_os)

  if [[ "$os" == "macos" ]]; then
    local download_url="https://github.com/nicklockwood/SwiftFormat/releases/download/${SWIFTFORMAT_VERSION}/swiftformat_macos.zip"
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT

    echo -e "${GREEN}Downloading SwiftFormat from GitHub...${NC}"

    if command_exists curl; then
      curl -L -o "$temp_dir/swiftformat.zip" "$download_url"
    elif command_exists wget; then
      wget -O "$temp_dir/swiftformat.zip" "$download_url"
    else
      echo -e "${RED}Neither curl nor wget found.${NC}"
      return 1
    fi

    unzip -o "$temp_dir/swiftformat.zip" -d "$temp_dir"
    mv "$temp_dir/swiftformat" "$install_dir/swiftformat"
    chmod +x "$install_dir/swiftformat"

    echo -e "${GREEN}SwiftFormat installed to $install_dir${NC}"
  else
    echo -e "${YELLOW}On Linux, SwiftFormat needs to be built from source.${NC}"
    echo -e "${YELLOW}Install Swift, then run:${NC}"
    echo "git clone https://github.com/nicklockwood/SwiftFormat.git && cd SwiftFormat && swift build -c release"
    return 1
  fi

  if [[ ":$PATH:" != *":$install_dir:"* ]]; then
    echo -e "${YELLOW}Add $install_dir to your PATH:${NC}"
    echo "export PATH=\"\$PATH:$install_dir\""
  fi

  return 0
}

verify_installation() {
  if command_exists swiftformat; then
    echo -e "${GREEN}SwiftFormat is installed and available${NC}"
    swiftformat --version 2>/dev/null || true
    return 0
  else
    echo -e "${RED}SwiftFormat is not available in PATH${NC}"
    return 1
  fi
}

main() {
  echo -e "${GREEN}SwiftFormat Installation Script${NC}"
  echo -e "${GREEN}================================${NC}"

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
      install_manual || install_result=$?
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
