# Addon K8GB

Upbound addon/controller package pair for [K8GB](https://www.k8gb.io/) — the
Kubernetes Global Balancer.

K8GB is a cloud native global load balancer that spreads application traffic
across Kubernetes clusters in different regions using standard DNS. It has no
dependency on a managed control plane: it runs entirely inside the clusters it
balances, serving the delegated GSLB zone from CoreDNS with the k8gb CRD
plugin, and reconciling `Gslb` and `ZoneDelegation` custom resources.

## Components

- **k8gb operator** — reconciles `Gslb` and `ZoneDelegation` resources, discovers
  healthy backends from Ingress/Gateway API/Istio, and writes `DNSEndpoint` records
- **CoreDNS with the k8gb CRD plugin** — serves the load-balanced DNS zone and the
  `gslb-ns-*` glue A records from the cluster
- **ExternalDNS (optional, `extdns.enabled`)** — syncs `DNSEndpoint` records to an
  edge DNS provider (Route53, Cloudflare, Infoblox, …)

## CRDs

| CRD | Purpose |
|---|---|
| `gslbs.k8gb.io` | Global load balancing strategy for an application |
| `zonedelegations.k8gb.io` | Dynamic activation of DNS zones |
| `dnsendpoints.externaldns.k8s.io` | DNS records for the edge provider (installed when `extdns.enabled=false`) |
| `gslbs.k8gb.absa.oss` | Legacy Gslb API (`k8gb.installLegacyCrds`) |

## Install

### As AddOn (UXP v2)

```yaml
apiVersion: pkg.upbound.io/v1beta1
kind: AddOn
metadata:
  name: k8gb
spec:
  package: xpkg.upbound.io/upbound/addon-k8gb:v0.1.0-rc1
```

### As Controller (Spaces)

```yaml
apiVersion: pkg.upbound.io/v1alpha1
kind: Controller
metadata:
  name: controller-k8gb
spec:
  package: xpkg.upbound.io/upbound/controller-k8gb:v0.1.0-rc1
```

## Configuration

K8GB **requires** per-cluster configuration — the shipped defaults
(`example.com` / `cloud.example.com`, geotag `eu`) are placeholders. Override
Helm values at install time using `AddOnRuntimeConfig`:

```yaml
apiVersion: pkg.upbound.io/v1beta1
kind: AddOnRuntimeConfig
metadata:
  name: k8gb-config
spec:
  helm:
    values:
      k8gb:
        # Unique geotag for this cluster
        clusterGeoTag: "eu-west-1"
        # Geotags of the other k8gb clusters
        extGslbClustersGeoTags: "us-east-1"
        dnsZones:
          - parentZone: "example.com"
            loadBalancedZone: "cloud.example.com"
            dnsZoneNegTTL: 30
        edgeDNSServers:
          - "1.1.1.1"
      coredns:
        serviceType: LoadBalancer
```

Every cluster in the GSLB mesh needs a distinct `clusterGeoTag`, and each
cluster's tag must appear in the other clusters' `extGslbClustersGeoTags`.

## Requirements

- Kubernetes >= 1.21.0 (chart `kubeVersion` constraint)
- UXP 2.x or Spaces with AddOn/Controller support
- A delegated DNS zone on an edge DNS provider, and CoreDNS reachable on port 53
  from that provider

## RBAC

Apply the `upbound-addon:k8gb` ClusterRole before installing. It grants the
`upbound-controller-manager` ServiceAccount the permissions needed to deploy
k8gb, and — because Kubernetes prevents privilege escalation — it is a superset
of the RBAC the chart itself creates.

```bash
kubectl apply -f manifests/addon-cluster-role.yaml
```

## Images

Upstream images are mirrored into `xpkg.upbound.io/upbound` by CI
(`hack/sync-images.sh`) and the packages point at the mirrors:

| Upstream | Mirror |
|---|---|
| `registry.k8gb.io/k8gb-io/k8gb` | `xpkg.upbound.io/upbound/k8gb` |
| `registry.k8gb.io/k8gb-io/k8s_crd` | `xpkg.upbound.io/upbound/k8gb-k8s-crd` |

## Development

### Building locally

```bash
source .chart-attributes
mkdir -p addon-package/helm addon-package/crds
cp addon.yaml addon-package/crossplane.yaml
helm pull $CHART_NAME --repo $REPO_URL --version $CHART_VERSION -d addon-package/helm
mv addon-package/helm/$CHART_NAME-$CHART_VERSION.tgz addon-package/helm/chart.tgz
# See .github/workflows/ci.yaml for the full build pipeline
```

### Testing

```bash
UP_CHART_VERSION=v0.1.0-rc1 up test run tests/* --e2e
```

## Upstream

- Chart: `k8gb/k8gb` v1.0.0 (App v1.0.0)
- Source: https://github.com/k8gb-io/k8gb
- License: Apache-2.0
