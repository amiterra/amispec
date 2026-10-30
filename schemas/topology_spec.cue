// SPDX-License-Identifier: Apache-2.0
// AmiSpec TopologyBlueprint meta-schema (normative)
// See docs/specification.adoc — Part III, TopologyBlueprint v1
// apiVersion: topology.amispec.io/v1
//
// Same package as component_passport.cue (shared types: #ScriptSpec,
// #CommandOrScriptRef, #ProbeSpec, #VolumeSpec).

package amispec

import "list"

#VolumeTopologyOverride: {
	sizeGb:           int
	committedSizeGb?: int
	mediaTier:        *"nvme-local" | "ssd-network" | "hdd-bulk" | "ram-tmpfs"
}

// Universal binding specification (central or inline)
#BindingSpec: {
	// from is required in clusters[].bindings[]; inferred from the owner in components[].bindings
	from?:          string
	to:             string
	toSlot?:        string
	asRequirement?: string
	envPrefix?:     string
	envOverrides?: [string]: string
	secretRotationEpoch?:     int & >=1 | *1
	type?:                    *"service-binding" | "live-migration-replica" | "oidc-protection"
	deliveryGuarantee?:       *"direct" | "transactional-outbox"
	outboxSourceRequirement?: string | *"database"
}

#TopologyBlueprint: {
	apiVersion: "topology.amispec.io/v1"
	kind:       "TopologyBlueprint"

	metadata: {
		projectId:    =~"^[a-z0-9-]+$"
		organization: string
		gitMode:      *"managed-embedded" | "byo-git"
	}

	macros?: [MacroName=string]:   string
	scripts?: [ScriptName=string]: #ScriptSpec

	externalResources?: [...{
		id:           =~"^[a-z0-9-]+$"
		passport:     string
		role:         "migration-source" | "hybrid-bridge" | "backup-vault"
		endpointFqdn: string
		port?:        int & >=1 & <=65535
		transport:    *"direct" | "wireguard-tunnel" | "mtls-gateway"
		region?:      string
		bucket?:      string
		exportedAttributes?: [string]: string | int | bool
		secretRef: =~"^sops://.*$"
	}]

	// Non-empty cluster list: a topology without clusters is meaningless
	clusters: [...{
		id:                 =~"^[a-z0-9-]+$"
		name:               string
		domain:             string
		k3sChannel:         string | *"v1.31"
		fleetCount?:        int & >=1
		maintenanceWindow?: string

		security: {
			// Non-empty list of public Age keys of all controllers + owner key
			sopsRecipients: [...=~"^age1[a-z0-9]+$"] & list.MinItems(1)
			implicitTelemetryLayer:  bool | *true
			imageRegistryPolicy:     *"local-p2p-cache" | "direct" | "airgapped-mirror"
			registryMirrorEndpoint?: string
			imagePullSecretRefs?: [...=~"^sops://.*$"]
			controlPlaneQuorumMode?: *"odd-etcd" | "witness-arbiter"
			etcdBackupTarget?:       string
		}

		cni: {
			engine:                  "cilium-ebpf"
			clusterMeshId:           int & >=1 & <=50
			kubeProxyReplacement:    true
			hubbleLiveMap:           bool | *true
			wireguardEncryption:     bool | *true
			mtuDiscoveryAndMssClamp: bool | *true
			fqdnCacheMinTtlSec:      int | *3600
		}

		nodes: [...{
			id:                 string
			role:               "control-plane-worker" | "control-plane-only" | "worker-only"
			pricingTier:        "micro-vps" | "standard-node" | "heavy-bare-metal"
			failureDomainZone?: string
			monthlyCostUsd?:    number
			hardware: {
				arch:                      *"amd64" | "arm64"
				cpuCores:                  number
				memoryMb:                  int
				systemReservedMb:          int | *1280
				kernelSlabReservePercent:  int | *3
				systemDiskReservedGb:      int | *40
				lvmSnapshotReservePercent: int | *10
				accelerators?: [...{
					resourceClass: string
					count:         int
					memoryGb?:     int
				}]
				disks: [...{
					name:   string
					tier:   "nvme-local" | "ssd-network" | "hdd-bulk"
					sizeGb: int
				}]
			}
		}]

		loadBalancers: [...{
			id:            string
			layer:         "edge-proxy" | "l7-gateway" | "l4-balancer"
			provider:      string
			upstreamEdge?: string
			trustedProxySource?: string | [...string]
			forwardingMode?:  *"ebpf-dsr-maglev" | "snat"
			floatingIpRef?:   string
			proxyProtocolV2?: bool
			http3Quic?:       bool | *true
			tls?:             *"letsencrypt-auto" | "letsencrypt-dns01-wildcard" | "letsencrypt-http01" | "custom-secret" | "none"
		}]

		securityZones?: [...{
			id:                   string
			name:                 string
			color:                string
			podSecurityStandard?: *"restricted" | "baseline" | "privileged"
			quotaCpuCores?:       number
			quotaMemoryMb?:       int
		}]

		logicalGroups?: [...{
			id:        string
			title:     string
			collapsed: bool | *false
		}]

		components: [...{
			id:                  =~"^[a-z0-9-]+$"
			passport:            string
			version:             string
			passportRev:         int & >=1
			zone?:               string
			group?:              string
			imagePullSecretRef?: =~"^sops://.*$"
			licenseSecretRef?:   =~"^sops://.*$"

			workloadOverride?: {
				image?:       string
				imageDigest?: =~"^sha256:[a-f0-9]{64}$"
				command?: [...string]
				args?: [...string]
				scheduleCron?:              string
				preDeployExpandCommand?:    #CommandOrScriptRef
				postDeployContractCommand?: #CommandOrScriptRef
				preScaleDownDrainCommand?:  #CommandOrScriptRef
			}

			config?: [ParamKey=string]: string | int | number | bool | [...string]

			topology: {
				mode:               "standalone" | "degraded-ha" | "strict-ha" | "sharded-cluster"
				replicas?:          int
				committedReplicas?: int
				shards?:            int
				autoscaling?: {
					minReplicas:       int & >=1
					maxReplicas:       int & >=1
					cooldownSeconds?:  int | *300
					targetCpuPercent?: int & >=10 & <=95
					customMetric?: {
						query:       string
						targetValue: number
					}
				}
			}

			resources: {
				cpuCores: number & >0
				memoryMb: int & >=64
			}

			storage?: #VolumeTopologyOverride
			volumes?: [VolumeName=string]: #VolumeTopologyOverride

			egressOverride?: {
				mode: "graph-only" | "allow-public-internet" | "allow-fqdn-whitelist"
				allowedFqdns?: [...string]
			}

			expose?: [...{
				endpoint:    string
				viaBalancer: string
				scope:       "public" | "protected"
				subdomain?:  string
				hostname?:   string
				pathPrefix?: string
				securityPolicy?: {
					clientAuth?: *"none" | "oidc" | "mtls"
					corsAllowedOrigins?: [...string]
					rateLimitRps?: int
				}
			}]

			bindings?: [...#BindingSpec]

			backupTarget?: string
			bootstrap?: {
				fromBackupTarget:    string
				sourceComponentId?:  string
				recoveryTargetTime?: *"latest" | string
			}
			}]

		bindings?: [...(#BindingSpec & {
			from: string
		})]
	}] & list.MinItems(1)

	crossClusterLinks?: [...{
		id:                string
		fromCluster:       string
		fromComponent:     string
		toCluster:         string
		toComponent:       string
		toSlot?:           string
		relationType:      "active-passive-replication" | "global-service-mesh" | "telemetry-and-events-uplink"
		transport:         *"wireguard-tunnel" | "mtls-gateway" | "direct"
		encryption:        *"wireguard-mtls" | "tls-strict"
		maxBandwidthMbps?: int
		rpoTargetSec?:     int
	}]
}

