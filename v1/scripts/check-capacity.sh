#!/bin/bash
# scripts/check-capacity.sh
# Check system resources and recommend preset

# Check for bc dependency
if ! command -v bc &> /dev/null; then
    echo "Error: 'bc' is required but not installed."
    echo "  On macOS: brew install bc"
    echo "  On Linux: apt-get install bc or yum install bc"
    exit 1
fi

echo "=== System Resource Check ==="
echo ""

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  TOTAL_CPUS=$(sysctl -n hw.logicalcpu)
  TOTAL_MEM_BYTES=$(sysctl -n hw.memsize)
  TOTAL_MEM_GB=$(echo "scale=1; $TOTAL_MEM_BYTES / 1024 / 1024 / 1024" | bc)
elif [[ -f /proc/meminfo ]]; then
  # Linux
  TOTAL_CPUS=$(nproc)
  TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  TOTAL_MEM_GB=$(echo "scale=1; $TOTAL_MEM_KB / 1024 / 1024" | bc)
else
  echo "⚠️  Unknown OS, cannot detect resources"
  exit 1
fi

echo "Detected Resources:"
echo "  CPUs: $TOTAL_CPUS"
echo "  Memory: ${TOTAL_MEM_GB}GB"
echo ""

# Calculate available memory (rough estimate)
if [[ "$OSTYPE" == "darwin"* ]]; then
  FREE_MEM_GB=$(echo "scale=1; $(vm_stat | head -1 | grep 'Pages free' | awk '{print $3}' | sed 's/\.//') * 16384 / 1024 / 1024 / 1024" | bc)
else
  FREE_MEM_GB=$(echo "scale=1; $(grep MemAvailable /proc/meminfo 2>/dev/null || grep MemFree /proc/meminfo | awk '{print $2}') / 1024 / 1024" | bc)
fi

echo "  Free Memory: ~${FREE_MEM_GB}GB"
echo ""

# Recommend preset
echo "=== Recommended Preset ==="
if (( $(echo "$TOTAL_MEM_GB < 8" | bc -l) )); then
  echo "⚠️  Warning: Less than 8GB RAM detected."
  echo "   Recommended: barebones (if you need streaming)"
  echo "   Note: This system may not have enough memory for the full stack."
elif (( $(echo "$TOTAL_MEM_GB < 12" | bc -l) )); then
  echo "✓ Recommended: minimal preset"
  echo "  Use 'barebones' if you don't need Superset"
elif (( $(echo "$TOTAL_MEM_GB < 24" | bc -l) )); then
  echo "✓ Recommended: default preset"
  echo "  Use 'minimal' if running other resource-heavy applications"
else
  echo "✓ Recommended: performance preset"
  echo "  You have plenty of resources!"
fi

echo ""
echo "=== Usage ==="
echo "  ./scripts/start.sh <preset>"
echo ""
echo "Available presets: barebones, minimal, default, performance"
