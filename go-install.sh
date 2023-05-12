#!/usr/bin/env bash

set -eou pipefail

TMPDIR=$(mktemp -d)
INPUT_REPOSITORY=$(basename "$INPUT_REPOSITORY")

if [[ "$INPUT_VERSION" == "latest" ]]; then
  echo "Downloading the latest release"
  # Set the latest release version
  VERSION=$(curl --silent -H "Authorization: token $INPUT_TOKEN" "https://api.github.com/repos/$INPUT_REPOSITORY_OWNER/$INPUT_REPOSITORY/releases/latest" | jq -r '.tag_name')
else
  echo "Downloading version $INPUT_VERSION"
  VERSION=$INPUT_VERSION
fi

NAME_VERSION=${VERSION#"v"}

# Determine the operating system and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

if [[ $OS == "darwin" ]]; then
  FILENAME="${INPUT_REPOSITORY}_${NAME_VERSION}_Darwin_x86_64.tar.gz"
  URL="https://github.com/$INPUT_REPOSITORY_OWNER/$INPUT_REPOSITORY/releases/download/${VERSION}/${FILENAME}"
  SHA256SUM_FILE="checksums.txt"
  SHA256SUM_URL="https://github.com/$INPUT_REPOSITORY_OWNER/$INPUT_REPOSITORY/releases/download/${VERSION}/${SHA256SUM_FILE}"
elif [[ $OS == "linux" ]]; then
  if [[ $ARCH == "x86_64" ]]; then
    FILENAME="${INPUT_REPOSITORY}_${NAME_VERSION}_Linux_x86_64.tar.gz"
    URL="https://github.com/$INPUT_REPOSITORY_OWNER/$INPUT_REPOSITORY/releases/download/${VERSION}/${FILENAME}"
    SHA256SUM_FILE="checksums.txt"
    SHA256SUM_URL="https://github.com/$INPUT_REPOSITORY_OWNER/$INPUT_REPOSITORY/releases/download/${VERSION}/${SHA256SUM_FILE}"
  else
    echo "Unsupported architecture: $ARCH"
    exit 1
  fi
elif [[ $OS == "windows" ]]; then
  if [[ $ARCH == "x86_64" ]]; then
    FILENAME="${INPUT_REPOSITORY}_${NAME_VERSION}_Windows_x86_64.zip"
    URL="https://github.com/$INPUT_REPOSITORY_OWNER/$INPUT_REPOSITORY/releases/download/${VERSION}/${FILENAME}"
    SHA256SUM_FILE="checksums.txt"
    SHA256SUM_URL="https://github.com/$INPUT_REPOSITORY_OWNER/$INPUT_REPOSITORY/releases/download/${VERSION}/${SHA256SUM_FILE}"
  else
    echo "Unsupported architecture: $ARCH"
    exit 1
  fi
else
  echo "Unsupported operating system: $OS"
  exit 1
fi

OUTPUT_FILE="$TMPDIR/$FILENAME"
SHA256SUM_OUTPUT_FILE="$TMPDIR/$SHA256SUM_FILE"

function download {
    local output=$1
    local url=$2

    for i in $(seq 1 5); do
      curl --fail --silent -H "Authorization: token $INPUT_TOKEN" --location --output "$output" "$url" && break
      sleep 10
      echo "$i retries"
    done
}

# Download the binary and its checksum file to the temporary directory
echo "Downloading $URL"
download "$OUTPUT_FILE" "$URL"
echo "Downloading $SHA256SUM_URL"
download "$SHA256SUM_OUTPUT_FILE" "$SHA256SUM_URL"

# Verify the checksum
EXPECTED=$(grep "$FILENAME" "$SHA256SUM_OUTPUT_FILE" | awk '{print $1}')
ACTUAL=$(sha256sum "$OUTPUT_FILE" | awk '{print $1}')
if [[ "$EXPECTED" != "$ACTUAL" ]]; then
  echo "Checksum verification failed"
  exit 1
fi

# Extract the binary in the temporary directory
if [[ $OS == "darwin" ]]; then
  tar -xzf "$OUTPUT_FILE" -C $TMPDIR
elif [[ $OS == "linux" ]]; then
  tar -xzf "$OUTPUT_FILE" -C $TMPDIR
elif [[ $OS == "windows" ]]; then
  unzip "$OUTPUT_FILE" -d $TMPDIR
else
  echo "Unsupported operating system: $OS"
  exit 1
fi

# Make the binary executable
chmod +x $TMPDIR/$INPUT_REPOSITORY

# Return the binary path
echo "binary_path=$TMPDIR/$INPUT_REPOSITORY" >> $GITHUB_OUTPUT
