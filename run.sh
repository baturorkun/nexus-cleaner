#!/bin/bash
set -euo pipefail

./cleaner.sh \
  --nexus-user="admin" \
  --nexus-passwd="admnin-passwd" \
  --nexus-url="https://nexus.domain.com" \
  --gitlab-url="https://gitlab.domain.com" \
  --gitlab-token="78Ybf-edT67-TYoh56" \
  --nexus-keep-tags="STG-1 STG-2" \
  --nexus-filter-images="^myproject-.*$"
