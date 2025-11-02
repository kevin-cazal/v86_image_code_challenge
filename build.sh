#!/bin/bash

# Local build script for v86 Alpine image
# This script replicates the GitHub Actions workflow locally

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Building v86 Alpine image...${NC}"
echo ""

# Get commit hash for tagging
COMMIT_HASH=$(git rev-parse --short HEAD)
IMAGE_NAME="v86-alpine-image"
IMAGE_TAG="${IMAGE_NAME}:${COMMIT_HASH}"

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    exit 1
fi

# Step 1: Prepare submodule
echo -e "${YELLOW}Preparing submodules...${NC}"
git submodule update --init --recursive

# Remove .git file from submodule so Docker includes the actual files
rm -f rootfs_overlay/opt/detect-language/.git

# Step 2: Build Docker image
echo -e "${YELLOW}Building Docker image (this may take a while)...${NC}"
docker build --platform linux/386 -t "$IMAGE_TAG" .

echo -e "${GREEN}✓ Docker image built${NC}"
echo ""

# Step 3: Export container to tar
echo -e "${YELLOW}Exporting container to tar...${NC}"
CONTAINER_NAME="alpine-v86-export"
OUT_ROOTFS_TAR="alpine-rootfs.tar"

# Create container from the built image
docker create --platform linux/386 -t -i --name "$CONTAINER_NAME" "$IMAGE_TAG"

# Export container to tar file
docker export "$CONTAINER_NAME" -o "$OUT_ROOTFS_TAR"

# Remove .dockerenv file
tar -f "$OUT_ROOTFS_TAR" --delete ".dockerenv" || true

# Clean up container
docker rm "$CONTAINER_NAME"

echo -e "${GREEN}✓ Container exported to $OUT_ROOTFS_TAR${NC}"
ls -lh "$OUT_ROOTFS_TAR"
echo ""

# Step 4: Create FSJSON and ROOTFS_FLAT
echo -e "${YELLOW}Creating FSJSON and ROOTFS_FLAT...${NC}"
OUT_FSJSON="alpine-fs.json"
OUT_ROOTFS_FLAT="alpine-rootfs-flat"

# Check if Python 3 is available
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    exit 1
fi

# Create FSJSON using fs2json.py tool
python3 tools/fs2json.py --out "$OUT_FSJSON" "$OUT_ROOTFS_TAR"

# Create ROOTFS_FLAT directory using copy-to-sha256.py tool
mkdir -p "$OUT_ROOTFS_FLAT"
python3 tools/copy-to-sha256.py "$OUT_ROOTFS_TAR" "$OUT_ROOTFS_FLAT"

echo -e "${GREEN}✓ FSJSON and ROOTFS_FLAT created${NC}"
ls -lh "$OUT_FSJSON"
echo ""

# Step 5: Install Node.js dependencies
echo -e "${YELLOW}Installing Node.js dependencies...${NC}"
if [ ! -d "node_modules" ]; then
    npm install
fi
echo -e "${GREEN}✓ Node.js dependencies ready${NC}"
echo ""

# Step 6: Generate state file
echo -e "${YELLOW}Generating v86 state file...${NC}"

# Create images directory structure
mkdir -p images

# Copy generated files to the expected locations
cp alpine-rootfs.tar images/alpine-rootfs.tar
cp alpine-fs.json images/alpine-fs.json
cp -r alpine-rootfs-flat images/alpine-rootfs-flat

# Run build-state.js
node tools/build-state.js

echo -e "${GREEN}✓ State file generated${NC}"
ls -lh images/alpine-state.bin
echo ""

# Show final results
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Generated files in ./images/:"
ls -lh images/

