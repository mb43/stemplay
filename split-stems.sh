#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# split-stems.sh  –  Batch split FLAC files into stems using Demucs
#
# Usage:
#   ./split-stems.sh /path/to/flac/files [output-folder]
#
# Output structure (ready for Stem Player):
#   output-folder/
#     Song Name/
#       vocals.wav
#       drums.wav
#       bass.wav
#       other.wav
# ─────────────────────────────────────────────────────────────────

set -e

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-./stems}"
MODEL="${DEMUCS_MODEL:-htdemucs}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${CYAN}  Stem Splitter – Batch FLAC → Stems  ${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo ""

# ── Check Python ──────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo -e "${RED}Error: python3 not found.${NC}"
  echo "Install Python from https://www.python.org or via: brew install python"
  exit 1
fi

# ── Check / install Demucs ────────────────────────────────────────
if ! python3 -m demucs --help &>/dev/null 2>&1; then
  echo -e "${YELLOW}Demucs not found. Installing...${NC}"
  pip3 install --user demucs
  echo ""
  if ! python3 -m demucs --help &>/dev/null 2>&1; then
    echo -e "${RED}Failed to install demucs. Try manually: pip3 install demucs${NC}"
    exit 1
  fi
  echo -e "${GREEN}Demucs installed successfully.${NC}"
  echo ""
fi

# ── Validate input folder ────────────────────────────────────────
if [ ! -d "$INPUT_DIR" ]; then
  echo -e "${RED}Error: Input folder not found: $INPUT_DIR${NC}"
  echo "Usage: ./split-stems.sh /path/to/flac/files [output-folder]"
  exit 1
fi

# ── Find FLAC files ──────────────────────────────────────────────
FLAC_FILES=()
while IFS= read -r -d '' f; do
  FLAC_FILES+=("$f")
done < <(find "$INPUT_DIR" -maxdepth 1 -type f -iname "*.flac" -print0 | sort -z)

if [ ${#FLAC_FILES[@]} -eq 0 ]; then
  echo -e "${RED}No .flac files found in: $INPUT_DIR${NC}"
  exit 1
fi

TOTAL=${#FLAC_FILES[@]}
echo -e "Input:   ${GREEN}$INPUT_DIR${NC}"
echo -e "Output:  ${GREEN}$OUTPUT_DIR${NC}"
echo -e "Model:   ${GREEN}$MODEL${NC}"
echo -e "Files:   ${GREEN}$TOTAL FLAC file(s)${NC}"
echo ""

# ── Estimate ─────────────────────────────────────────────────────
echo -e "${YELLOW}Estimated time: ~1-3 min per song on Apple Silicon, ~3-8 min on Intel.${NC}"
echo ""

# ── Process each file ────────────────────────────────────────────
DONE=0
FAILED=0

for flac in "${FLAC_FILES[@]}"; do
  DONE=$((DONE + 1))
  BASENAME="$(basename "$flac" .flac)"
  echo -e "${CYAN}[$DONE/$TOTAL]${NC} Processing: ${GREEN}$BASENAME${NC}"

  if python3 -m demucs \
    --name "$MODEL" \
    --out "$OUTPUT_DIR" \
    "$flac" 2>&1 | while IFS= read -r line; do
      # Show progress lines from demucs
      if [[ "$line" == *"%"* ]]; then
        printf "\r  %s" "$line"
      fi
    done; then
    echo ""
    echo -e "  ${GREEN}Done${NC}"
  else
    echo ""
    echo -e "  ${RED}Failed${NC}"
    FAILED=$((FAILED + 1))
  fi
  echo ""
done

# ── Reorganize output ────────────────────────────────────────────
# Demucs outputs to: OUTPUT_DIR/MODEL/songname/stem.wav
# Flatten to: OUTPUT_DIR/songname/stem.wav for the web player
DEMUCS_OUT="$OUTPUT_DIR/$MODEL"
if [ -d "$DEMUCS_OUT" ]; then
  echo -e "${CYAN}Reorganizing for Stem Player...${NC}"
  for songdir in "$DEMUCS_OUT"/*/; do
    songname="$(basename "$songdir")"
    target="$OUTPUT_DIR/$songname"
    if [ "$songdir" != "$target/" ]; then
      mkdir -p "$target"
      mv "$songdir"*.wav "$target/" 2>/dev/null || true
      rmdir "$songdir" 2>/dev/null || true
    fi
  done
  rmdir "$DEMUCS_OUT" 2>/dev/null || true
  echo -e "${GREEN}Done.${NC}"
  echo ""
fi

# ── Summary ──────────────────────────────────────────────────────
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "  Processed: ${GREEN}$((TOTAL - FAILED))${NC} / $TOTAL"
if [ $FAILED -gt 0 ]; then
  echo -e "  Failed:    ${RED}$FAILED${NC}"
fi
echo -e ""
echo -e "  Stems ready in: ${GREEN}$OUTPUT_DIR${NC}"
echo -e ""
echo -e "  ${YELLOW}Next step:${NC} Open Stem Player, click import,"
echo -e "  and select the ${GREEN}$OUTPUT_DIR${NC} folder."
echo -e "${CYAN}══════════════════════════════════════${NC}"
