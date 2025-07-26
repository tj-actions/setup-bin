#!/usr/bin/env bash

set -eou pipefail

TMPDIR=$(mktemp -d)
INPUT_REPOSITORY=$(basename "$INPUT_REPOSITORY")

if [[ "$INPUT_VERSION" == "latest" ]]; then
  echo "Downloading the latest release"
  # Set the latest release version
  VERSION=$(curl --silent -H "Authorization: token $INPUT_TOKEN" "https://api.github.com/repos/$INPUT_REPOSITORY_OWNER/$INPUT_REPOSITORY/releases/latest" | jq -r '.tag_name')

  # If the version is in the format like "v3", find the latest semver
  if [[ $VERSION =~ ^v[0-9]+$ ]]; then
    # Get all releases and sort them semantically
    VERSION=$(curl --silent -H "Authorization: token $INPUT_TOKEN" "https://api.github.com/repos/$INPUT_REPOSITORY_OWNER/$INPUT_REPOSITORY/releases" | jq -r '
      [.[] | .tag_name] | 
      map(select(test("^v[0-9]"))) | 
      sort_by(. | ltrimstr("v") | split(".") | map(tonumber? // 0)) | 
      reverse | 
      .[0]
    ')
  fi
else
  echo "Downloading version $INPUT_VERSION"
  VERSION="$INPUT_VERSION"
fi

echo "VERSION: $VERSION"
echo "INPUT_ADD_PREFIX_TO_VERSION: $INPUT_ADD_PREFIX_TO_VERSION"

NAME_VERSION="${VERSION#"v"}"

if [ "$INPUT_ADD_PREFIX_TO_VERSION" == "true" ]; then
  echo "Adding v to the version"
  NAME_VERSION="v$NAME_VERSION"
fi

# Determine the operating system and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

echo "OS: $OS"
echo "ARCH: $ARCH"

# Function to try downloading with different filename patterns
function try_download {
    local base_url="https://github.com/$INPUT_REPOSITORY_OWNER/$INPUT_REPOSITORY/releases/download/${VERSION}"
    local patterns=("$@")
    
    for pattern in "${patterns[@]}"; do
        local filename="$pattern"
        local url="$base_url/$filename"
        
        echo "Checking for file: $filename"
        
        # Check if file exists using HEAD request (no download)
        if curl --fail --silent -H "Authorization: token $INPUT_TOKEN" --head "$url" > /dev/null; then
            echo "Found file: $filename"
            FILENAME="$filename"
            URL="$url"
            
            # Try to find checksum file
            local sha256sum_file="${filename}.sha256sum"
            local sha512_file="${filename}.sha512"
            local sha256sum_url="$base_url/$sha256sum_file"
            local sha512_url="$base_url/$sha512_file"
            
            # Try sha256sum first, then sha512
            if curl --fail --silent -H "Authorization: token $INPUT_TOKEN" --head "$sha256sum_url" > /dev/null; then
                echo "Found checksum file: $sha256sum_file"
                SHA256SUM_FILE="$sha256sum_file"
                SHA256SUM_URL="$sha256sum_url"
                CHECKSUM_TYPE="sha256sum"
            elif curl --fail --silent -H "Authorization: token $INPUT_TOKEN" --head "$sha512_url" > /dev/null; then
                echo "Found checksum file: $sha512_file"
                SHA256SUM_FILE="$sha512_file"
                SHA256SUM_URL="$sha512_url"
                CHECKSUM_TYPE="sha512"
            else
                echo "Warning: No checksum file found for $filename"
                SHA256SUM_FILE=""
                SHA256SUM_URL=""
                CHECKSUM_TYPE="none"
            fi
            
            return 0
        fi
    done
    
    echo "No matching files found for any pattern"
    return 1
}

# Define filename patterns for each platform
if [[ $OS == "darwin" ]]; then
  if [[ $ARCH == "arm64" || $ARCH == "aarch64" ]]; then
    patterns=(
      "${INPUT_REPOSITORY}-${NAME_VERSION}-aarch64-apple-darwin.tar.gz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_aarch64-apple-darwin.zip"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-aarch64-apple-darwin.zip"
      # Fallback to x86_64
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-apple-darwin.tar.gz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-apple-darwin.zip"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-apple-darwin.zip"
    )
  else
    patterns=(
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-apple-darwin.tar.gz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-apple-darwin.zip"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-apple-darwin.zip"
    )
  fi
elif [[ $OS == "linux" ]]; then
  if [[ $ARCH == "x86_64" ]]; then
    patterns=(
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-unknown-linux-musl.tar.gz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-unknown-linux-musl.tar.gz"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-unknown-linux-musl.tar.xz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-unknown-linux-musl.tar.xz"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-unknown-linux-musl.tar.zst"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-unknown-linux-musl.tar.zst"
    )
  elif [[ $ARCH == "aarch64" || $ARCH == "arm64" ]]; then
    patterns=(
      "${INPUT_REPOSITORY}-${NAME_VERSION}-aarch64-unknown-linux-musl.tar.gz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_aarch64-unknown-linux-musl.tar.gz"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-aarch64-unknown-linux-musl.tar.xz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_aarch64-unknown-linux-musl.tar.xz"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-aarch64-unknown-linux-musl.tar.zst"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_aarch64-unknown-linux-musl.tar.zst"
      # Fallback to x86_64
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-unknown-linux-musl.tar.gz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-unknown-linux-musl.tar.gz"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-unknown-linux-musl.tar.xz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-unknown-linux-musl.tar.xz"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-unknown-linux-musl.tar.zst"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-unknown-linux-musl.tar.zst"
    )
  elif [[ $ARCH == "i686" || $ARCH == "i386" ]]; then
    patterns=(
      "${INPUT_REPOSITORY}-${NAME_VERSION}-i686-unknown-linux-musl.tar.gz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_i686-unknown-linux-musl.tar.gz"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-i686-unknown-linux-musl.tar.xz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_i686-unknown-linux-musl.tar.xz"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-i686-unknown-linux-musl.tar.zst"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_i686-unknown-linux-musl.tar.zst"
      # Fallback to x86_64
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-unknown-linux-musl.tar.gz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-unknown-linux-musl.tar.gz"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-unknown-linux-musl.tar.xz"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-unknown-linux-musl.tar.xz"
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-unknown-linux-musl.tar.zst"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-unknown-linux-musl.tar.zst"
    )
  else
    echo "Unsupported architecture: $ARCH"
    exit 1
  fi
elif [[ $OS == *"mingw64"* ]]; then
  if [[ $ARCH == "x86_64" ]]; then
    patterns=(
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-pc-windows-gnu.zip"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-pc-windows-gnu.zip"
    )
  elif [[ $ARCH == "aarch64" || $ARCH == "arm64" ]]; then
    patterns=(
      "${INPUT_REPOSITORY}-${NAME_VERSION}-aarch64-pc-windows-msvc.zip"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_aarch64-pc-windows-msvc.zip"
      # Fallback to x86_64
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-pc-windows-gnu.zip"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-pc-windows-gnu.zip"
    )
  elif [[ $ARCH == "i686" || $ARCH == "i386" ]]; then
    patterns=(
      "${INPUT_REPOSITORY}-${NAME_VERSION}-i686-pc-windows-msvc.zip"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_i686-pc-windows-msvc.zip"
      # Fallback to x86_64
      "${INPUT_REPOSITORY}-${NAME_VERSION}-x86_64-pc-windows-gnu.zip"
      "${INPUT_REPOSITORY}_${NAME_VERSION}_x86_64-pc-windows-gnu.zip"
    )
  else
    echo "Unsupported architecture: $ARCH"
    exit 1
  fi
else
  echo "Unsupported operating system: $OS"
  exit 1
fi

# Try to find a matching file
if ! try_download "${patterns[@]}"; then
  echo "Failed to find any matching files for $OS/$ARCH"
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

if [[ -n "$SHA256SUM_URL" ]]; then
  echo "Downloading $SHA256SUM_URL"
  download "$SHA256SUM_OUTPUT_FILE" "$SHA256SUM_URL"
else
  echo "No checksum file to download"
fi

# Verify the checksum
if [[ "$CHECKSUM_TYPE" == "sha256sum" ]]; then
  EXPECTED=$(grep "$FILENAME" "$SHA256SUM_OUTPUT_FILE" | awk '{print $1}')
elif [[ "$CHECKSUM_TYPE" == "sha512" ]]; then
  EXPECTED=$(grep "$FILENAME" "$SHA256SUM_OUTPUT_FILE" | awk '{print $1}')
else
  echo "No checksum file found, skipping verification."
  EXPECTED=""
fi

if [[ -n "$EXPECTED" ]]; then
  if [[ $OS == "darwin" ]]; then
    if [[ "$CHECKSUM_TYPE" == "sha512" ]]; then
      ACTUAL=$(shasum -a 512 "$OUTPUT_FILE" | awk '{print $1}')
    else
      ACTUAL=$(shasum -a 256 "$OUTPUT_FILE" | awk '{print $1}')
    fi
  elif [[ $OS == "linux" ]]; then
    if [[ "$CHECKSUM_TYPE" == "sha512" ]]; then
      ACTUAL=$(sha512sum "$OUTPUT_FILE" | awk '{print $1}')
    else
      ACTUAL=$(sha256sum "$OUTPUT_FILE" | awk '{print $1}')
    fi
  elif [[ $OS == *"mingw64"* ]]; then
    if [[ "$CHECKSUM_TYPE" == "sha512" ]]; then
      ACTUAL=$(sha512sum "$OUTPUT_FILE" | awk '{print $1}')
    else
      ACTUAL=$(sha256sum "$OUTPUT_FILE" | awk '{print $1}')
    fi
  else
    echo "Unsupported operating system: $OS"
    exit 1
  fi

  if [[ "$EXPECTED" != "$ACTUAL" ]]; then
    echo "Checksum verification failed"
    echo "Expected: $EXPECTED"
    echo "Actual: $ACTUAL"
    exit 1
  fi
  
  echo "Checksum verification passed"
else
  echo "Skipping checksum verification"
fi

# Extract the binary in the temporary directory to a subdirectory named after the repository
if [[ $FILENAME == *.zip ]]; then
  unzip "$OUTPUT_FILE" -d "$TMPDIR"
elif [[ $FILENAME == *.tar.gz ]]; then
  tar -xzf "$OUTPUT_FILE" -C "$TMPDIR"
elif [[ $FILENAME == *.tar.xz ]]; then
  tar -xf "$OUTPUT_FILE" -C "$TMPDIR"
elif [[ $FILENAME == *.tar.zst ]]; then
  # Try tar with --zstd flag first, fallback to zstd pipe if not supported
  if tar --help 2>&1 | grep -q -- --zstd; then
    tar --zstd -xf "$OUTPUT_FILE" -C "$TMPDIR"
  else
    zstd -dc "$OUTPUT_FILE" | tar -xf - -C "$TMPDIR"
  fi
else
  echo "Unsupported file format: $FILENAME"
  exit 1
fi

# Try to find the binary with the repository name
BINARY_PATH=""

# First, try to find the binary with the exact repository name
if [[ -f "$TMPDIR/$INPUT_REPOSITORY" ]]; then
  BINARY_PATH="$TMPDIR/$INPUT_REPOSITORY"
elif [[ -f "$TMPDIR/$INPUT_REPOSITORY.exe" ]]; then
  BINARY_PATH="$TMPDIR/$INPUT_REPOSITORY.exe"
else
  # Search recursively for the binary with repository name
  if [[ $OS == "darwin" ]]; then
    # macOS compatible find command
    BINARY_PATH=$(find "$TMPDIR" -name "$INPUT_REPOSITORY" -type f -perm +111 | head -n 1)
  else
    # Linux and other systems
    BINARY_PATH=$(find "$TMPDIR" -name "$INPUT_REPOSITORY" -type f -executable | head -n 1)
  fi
  
  # If not found, try with .exe extension
  if [[ -z "$BINARY_PATH" ]]; then
    if [[ $OS == "darwin" ]]; then
      BINARY_PATH=$(find "$TMPDIR" -name "$INPUT_REPOSITORY.exe" -type f -perm +111 | head -n 1)
    else
      BINARY_PATH=$(find "$TMPDIR" -name "$INPUT_REPOSITORY.exe" -type f -executable | head -n 1)
    fi
  fi
fi

if [[ -z "$BINARY_PATH" ]]; then
  echo "Error: Could not find executable binary '$INPUT_REPOSITORY' after extraction"
  echo "Contents of $TMPDIR:"
  find "$TMPDIR" -type f
  exit 1
fi

echo "Found binary: $BINARY_PATH"

# Make the binary executable
chmod +x "$BINARY_PATH"

# Return the binary path
echo "binary_path=$BINARY_PATH" >> "$GITHUB_OUTPUT"
