#!/usr/bin/env bash
# Root filesystem usage percentage (number only) for the DISK ring.
df --output=pcent / 2>/dev/null | tail -1 | tr -dc '0-9'
echo
