package amispec

// Unit tests for meta-schema constraints (run with `cue test ./schemas/...`).
// Each field that fails to unify is a failed test — CUE evaluation is the assertion.

// --- #TunableValue ---

_testTunableMax: #TunableValue & {
	value:         1600000
	mergeStrategy: "max"
}

_testTunableMin: #TunableValue & {
	value:         1
	mergeStrategy: "min"
}

_testTunableExclusive: #TunableValue & {
	value:         "never"
	mergeStrategy: "exclusive-match"
}

// --- #ScriptSpec ---

_testScriptDefaults: #ScriptSpec & {
	runtime: "posix-sh"
	inline:  "true"
	// timeoutSeconds defaults to 300, mountAsSecret to false
}

_testScriptSql: #ScriptSpec & {
	runtime:        "sql"
	path:           "scripts/seed.sql"
	timeoutSeconds: 60
	mountAsSecret:  true
}

// --- #CommandOrScriptRef ---

_testCmdArray: #CommandOrScriptRef & ["/bin/true", "--ok"]

_testCmdScriptRef: #CommandOrScriptRef & {
	scriptRef: "passport://scripts/seed"
	args: ["--strict"]
}

// --- #ProbeSpec ---

_testProbeHttp: #ProbeSpec & {
	type:   "http"
	scheme: "HTTPS"
	path:   "/health"
	port:   8443
}

_testProbeExec: #ProbeSpec & {
	type: "exec"
	command: ["pgrep", "-f", "worker"]
}

// --- #VolumeSpec ---

_testVolume: #VolumeSpec & {
	mountPath:     "/var/lib/data"
	minSizeGb:     10
	defaultSizeGb: 50
	lvmOptions: {
		provisioner:       "topolvm-nvme"
		volumeBindingMode: "WaitForFirstConsumer"
		mountFlags: ["noatime", "nodiratime", "discard"]
	}
}

// #MountFlag accepts only the closed set
_testMountFlag: #MountFlag & "noatime"
_testMountFlagList: [...#MountFlag] & ["ro", "nosuid"]

// --- #ComponentPassport (minimal happy path) ---

_testPassportMinimal: #ComponentPassport & {
	apiVersion: "catalog.amispec.io/v1"
	kind:       "ComponentPassport"
	metadata: {
		id:          "demo-worker"
		name:        "Demo Worker"
		version:     "1.0.0"
		passportRev: 1
		category:    "application"
		archetype:   "stateless-app"
		distribution: {
			tier:    "open-core"
			license: "Apache-2.0"
		}
		canvasUI: {
			icon:        "worker"
			accentColor: "#2563EB"
			nodeShape:   "standard-card"
		}
	}
	topologyModes: {
		standalone: {
			description:     "1 replica"
			minNodes:        1
			replicas:        1
			scaleDownPolicy: "immediate"
			disruptionBudget: {
				maxUnavailable: 1
				updateStrategy: "rolling"
			}
			podAntiAffinity: "soft"
		}
	}
	workload: {
		engine:        "k8s-deployment"
		priorityClass: "background-batch"
		container: {
			image:                  "ghcr.io/example/worker:1.0.0"
			readOnlyRootFilesystem: true
		}
	}
	interfaces: {
		egressDefaultMode: "graph-only"
		endpoints: []
		provides: []
		requires: {}
	}
	hardwareAndKernel: {
		resources: {
			minCpuCores:         0.25
			minMemoryMb:         128
			recommendedMemoryMb: 512
		}
	}
	operations: {
		observability: {
			scrapeInterval: "30s"
		}
	}
}

// Defaults applied by the schema
_testPassportDefaults:   _testPassportMinimal.hardwareAndKernel.resources.ephemeralStorageMb & 2048
_testPassportOomDefault: _testPassportMinimal.hardwareAndKernel.resources.oomSafetyMarginPercent & 15

// --- #TopologyBlueprint (minimal happy path) ---

_testTopologyMinimal: #TopologyBlueprint & {
	apiVersion: "topology.amispec.io/v1"
	kind:       "TopologyBlueprint"
	metadata: {
		projectId:    "demo"
		organization: "example"
		gitMode:      "managed-embedded"
	}
	clusters: [{
		id:     "local"
		name:   "Local"
		domain: "example.local"
		security: {
			sopsRecipients: ["age1examplepublickey00000000000000000000000000000000000000"]
		}
		cni: {
			engine:               "cilium-ebpf"
			clusterMeshId:        1
			kubeProxyReplacement: true
		}
		nodes: [{
			id:          "n1"
			role:        "control-plane-worker"
			pricingTier: "micro-vps"
			hardware: {
				arch:     "amd64"
				cpuCores: 2
				memoryMb: 4096
				disks: [{
					name:   "d0"
					tier:   "nvme-local"
					sizeGb: 50
				}]
			}
		}]
		components: []
	}]
}

_testTopologyCidrDefault: _testTopologyMinimal.clusters[0].cni.wireguardEncryption & true
_testTopologyFqdnDefault: _testTopologyMinimal.clusters[0].cni.fqdnCacheMinTtlSec & 3600

// --- #BindingSpec ---

_testBinding: #BindingSpec & {
	to:                  "pg-main"
	toSlot:              "sql-cluster"
	asRequirement:       "database"
	secretRotationEpoch: 1
	type:                "service-binding"
	deliveryGuarantee:   "direct"
}

_testBindingOutbox: #BindingSpec & {
	to:                      "sqs"
	asRequirement:           "queue"
	deliveryGuarantee:       "transactional-outbox"
	outboxSourceRequirement: "database"
}

// --- #CanvasLayout ---

_testCanvasLayout: #CanvasLayout & {
	apiVersion: "topology.amispec.io/v1"
	kind:       "CanvasLayout"
	clusterId:  "prod"
	viewport: {x: 0, y: 0, zoom: 1}
	positions: {
		web: {x: 10, y: 20}
	}
}

_testCanvasZoomDefaultCollapsed: #CanvasLayout & {
	apiVersion: "topology.amispec.io/v1"
	kind:       "CanvasLayout"
	clusterId:  "prod"
	groups: {
		g1: {}
	}
}

// Expected default collapsed=false
_testCollapsedDefault: _testCanvasZoomDefaultCollapsed.groups.g1.collapsed & false
