#!/bin/zsh
# Builds and runs the computer-side checks of the shared code in Core/.
cd "$(dirname "$0")/.." && swiftc -O Core/*.swift tests/main.swift -o tests/harness 2>&1 | grep -E "error" ; ./tests/harness
