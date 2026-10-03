#!/usr/bin/env bash
for t in az terraform ansible docker kubectl helm k6 hey gh jq make; do
  if command -v "$t" >/dev/null 2>&1; then printf "ok      %s\n" "$t"; else printf "MISSING %s\n" "$t"; fi
done
