#!/bin/sh
set -eo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <chart-version> <chart-url>"
  exit 1
fi

CHART_VERSION="$1"
REPO_URL="$2"
CHART="k8gb/k8gb"

helm repo add k8gb $REPO_URL

if ! helm images --help >/dev/null 2>&1; then
  echo "helm-images plugin is not installed."
  echo "Install it with: helm plugin install https://github.com/nikhilsbhat/helm-images"
  exit 1
fi

if ! command -v crane >/dev/null 2>&1; then
  echo "crane is not installed."
  exit 1
fi

MAPPINGS="registry.k8gb.io/k8gb-io/k8gb xpkg.upbound.io/upbound/k8gb
registry.k8gb.io/k8gb-io/k8s_crd xpkg.upbound.io/upbound/k8gb-k8s-crd
registry.k8s.io/external-dns/external-dns xpkg.upbound.io/upbound/k8gb-external-dns
otel/opentelemetry-collector xpkg.upbound.io/upbound/k8gb-opentelemetry-collector
jaegertracing/all-in-one xpkg.upbound.io/upbound/k8gb-jaeger-all-in-one
"

# Get image list from Helm chart
images=$(helm images get "$CHART" --version="$CHART_VERSION" --skip-tests | sort | uniq)

echo "$images" | while read -r image; do
  [ -z "$image" ] && continue

  repo_and_name=$(echo "$image" | sed 's/:.*$//')
  tag=$(echo "$image" | sed 's/^.*://')

  source_image="$image"
  lookup_key="$repo_and_name"

  dest_repo=$(echo "$MAPPINGS" | awk -v key="$lookup_key" '$1 == key { print $2 }')

  if [ -z "$dest_repo" ]; then
    echo "No mapping for $lookup_key, skipping..."
    continue
  fi

  dest_image="${dest_repo}:${tag}"
  echo "Copying $source_image -> $dest_image"
  crane copy "$source_image" "$dest_image"
done
