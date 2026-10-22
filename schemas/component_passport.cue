// SPDX-License-Identifier: Apache-2.0
// AmiSpec ComponentPassport meta-schema (normative)
// See docs/specification.adoc — Part III, ComponentPassport v1
// apiVersion: catalog.amispec.io/v1
//
// Standalone package `amispec` (CUE). Validates ComponentPassport documents.

package amispec

// Polymorphic kernel parameter (sysctl / sysfs) with profile merge strategy
#TunableValue: {
	value:         int | string | bool
	mergeStrategy: *"max" | "min" | "exclusive-match"
}

// Typed runtime script; compiled into ConfigMap/Secret -<sha8>
#ScriptSpec: {
	runtime:        *"posix-sh" | "sql" | "python"
	path?:          string
	inline?:        string
	timeoutSeconds: int | *300
	mountAsSecret:  bool | *false
}

// Direct argument array or a named script reference
#CommandOrScriptRef: [...string] | {
	scriptRef: =~"^(passport|topology)://scripts/[a-zA-Z0-9_.-]+$"
	args?: [...string]
}

// Health probe: http | tcp | grpc | exec
#ProbeSpec: {
	type:                *"http" | "tcp" | "grpc" | "exec"
	scheme?:             *"HTTP" | "HTTPS"
	path?:               string
	port?:               int
	command?:            #CommandOrScriptRef
	localProcessOnly?:   bool | *true
	checkLocalSidecars?: bool | *true
	failureThreshold:    int | *3
	periodSeconds:       int | *10
	timeoutSeconds:      int | *3
}

// Allowed Linux/CSI mount flags (closed set; typos fail at validation).
// Dangerous flags (`suid`, `exec`, `dev`, `user`) are intentionally excluded.
#MountFlag:
	"noatime" | "nodiratime" | "relatime" | "strictatime" | "lazytime" |
	"sync" | "dirsync" | "async" |
	"ro" | "rw" |
	"discard" | "nodiscard" |
	"noexec" | "nosuid" | "nodev" |
	"norecovery" | "nouuid" | "nobarrier" | "barrier"

// Storage volume specification
#VolumeSpec: {
	mountPath:        string
	minSizeGb:        int
	defaultSizeGb:    int
	resizePolicy:     *"expand-only-monotonic" | "immutable"
	deletionPolicy:   *"retain" | "delete"
	nodeLossRecovery: *"rehydrate-from-backup" | "reseed-from-peer" | "manual-wait"
	mediaTier:        *"nvme-local" | "ssd-network" | "hdd-bulk" | "ram-tmpfs"
	diskExclusive:    bool | *false
	lvmOptions: {
		provisioner:       *"topolvm-nvme" | "local-path" | "external-csi"
		volumeBindingMode: *"WaitForFirstConsumer" | "Immediate"
		mountFlags:        [...#MountFlag] | *["noatime", "nodiratime"]
		filesystem:        *"xfs" | "ext4"
		emergencyBallastMb: int | *1024
	}
}

#ComponentPassport: {
	apiVersion: "catalog.amispec.io/v1"
	kind:       "ComponentPassport"

	// 1. Metadata, distribution, visualization
	metadata: {
		id:          =~"^[a-z0-9-]+$"
		name:        string
		version:     string
		passportRev: int & >=1
		category:    "database" | "analytics" | "cache" | "message-queue" | "application" | "ai-ml" | "gateway" | "observability" | "storage" | "security" | "external"
		archetype:   "stateless-app" | "stateful-service" | "operator-cluster" | "edge-gateway" | "external-bridge" | "scheduled-job"

		distribution: {
			tier:    *"open-core" | "private-custom"   // MVP: open vs private passport
			license: string | *"Apache-2.0"
			vendor?: {
				name:               string
				requiresLicenseKey: bool | *false
			}
		}

		canvasUI: {
			icon:        string
			accentColor: =~"^#[0-9a-fA-F]{6}$"
			nodeShape:   *"standard-card" | "database-cylinder" | "queue-pipe" | "gateway-shield" | "external-cloud"
			badges?: [...string]
			cardPinnedFields?: [...string]
			quickControls?: [...{
				field:   string
				label:   string
				control: "select" | "slider" | "toggle" | "number"
			}]
		}
	}

	// 2. User parameters (config contract / UI inspector)
	parameters?: [ParamKey=string]: {
		label: string
		type:  "string" | "int" | "number" | "bool" | "enum" | "string-list" | "secret-ref"
		default?: string | int | number | bool | [...string]
		enumValues?: [...string]
		min?:         number
		max?:         number
		visibleWhen?: string
		targetPath?:  string
		applyImpact:  *"pod-restart" | "hot-reload" | "rolling-switchover" | "immutable"
		uiControl?:   *"input" | "number" | "slider" | "select" | "toggle" | "tags"
	}

	// 2b. CEL compile-time macros and runtime scripts
	macros?: [MacroName=string]:   string
	scripts?: [ScriptName=string]: #ScriptSpec

	// 3. Topology modes, quorums, PDB
	topologyModes: [ModeName=string]: {
		description:     string
		minNodes:        int & >=1
		replicas:        int | string
		maxReplicas?:    int
		scaleDownPolicy: *"safe-drain-required" | "immediate"
		quorumType?:     "none" | "raft-odd" | "primary-standby" | "witness-assisted"
		quorumArbiter?:  "none" | "witness-pod" | "cloud-lease-fencing"
		witnessComponent?: {
			enabled:       bool
			replicas:      int & >=1 | *1
			image:         string
			cpuMillicores: int & <=1000 | *100
			memoryMb:      int & <=512
			placement:     *"control-plane-or-third-fault-domain" | "dedicated-per-node"
		}
		disruptionBudget: {
			maxUnavailable: int | string | *1
			updateStrategy: *"rolling" | "primary-last" | "recreate"
		}
		podAntiAffinity: *"soft" | "spread-skew-1" | "hard-per-node" | "hard-per-zone" | "hard-per-disk"
		uiWarning?:      string
	}

	// 4. Workload engine
	workload: {
		engine:                "k8s-deployment" | "k8s-statefulset" | "k8s-daemonset" | "k8s-cronjob" | "flux-helm-release" | "operator-crd"
		allowWorkloadOverride: bool | *false
		peerDiscovery?:        *"none" | "headless-early-dns"
		priorityClass:         *"auto-by-archetype" | "system-critical" | "stateful-core" | "stateless-web" | "background-batch"

		schedule?: {
			cron:              string
			concurrencyPolicy: *"Forbid" | "Replace" | "Allow"
			timeoutSeconds?:   int | *3600
		}

		container?: {
			image:                  string
			imageDigest?:           =~"^sha256:[a-f0-9]{64}$"
			pullSecretRequired:     bool | *false
			readOnlyRootFilesystem: bool | *true
			securityContext?: {
				runAsNonRoot: bool | *true
				runAsUser:    int | *10001
				fsGroup:      int | *10001
			}
			command?: [...string]
			args?: [...string]
			zeroEndpoints: bool | *false
		}

		companions?: [...{
			name:         string
			image:        string
			imageDigest?: =~"^sha256:[a-f0-9]{64}$"
			ports?: [...int]
			command?: [...string]
			args?: [...string]
			memoryMb: int
			cpuCores: number
			mountPaths?: [...string]
		}]

		probes?: {
			startup?: #ProbeSpec & {failureThreshold: int | *30, periodSeconds: int | *2}
			liveness?: #ProbeSpec & {localProcessOnly: true}
			readiness?: #ProbeSpec & {checkLocalSidecars: bool | *true, periodSeconds: int | *5}
		}

		lifecycle?: {
			preDeployExpandCommand?:    #CommandOrScriptRef
			postDeployContractCommand?: #CommandOrScriptRef
			preScaleDownDrainCommand?:  #CommandOrScriptRef
			jobTimeoutSec:              int | *600
			jobBackoffLimit:            int | *3
			rollingUpdateSurgePolicy:   *"adaptive-zero-surge-on-tight-ram" | "strict-surge"
			preStopSleepSec:            int | *5
			gracefulStopTimeoutSec:     int | *35
		}

		helmSpec?: {
			repository:      string
			chart:           string
			version:         string
			chartDigest?:    =~"^sha256:[a-f0-9]{64}$"
			valuesTemplate?: string
		}

		operatorSpec?: {
			operatorHelmChart: string
			operatorVersion:   string
			crdApiVersion:     string
			crdKind:           string
			manifestTemplate:  string
		}

		configFormulas?: [ParamName=string]: {
			cel:         string
			unit?:       "MB" | "GB" | "bytes" | "count" | "string"
			targetPath:  string
			applyImpact: *"hot-reload" | "rolling-switchover" | "pod-restart"
			description: string
		}

		configMounts?: [...{
			name:           string
			mountPath:      string
			subPath?:       string
			fromSecret:     bool | *true
			reloadStrategy: *"pod-restart" | "hot-inotify" | "sighup"
		}]
	}

	// 5. Interfaces, client contract, provisioner
	interfaces: {
		egressDefaultMode: *"graph-only" | "allow-public-internet" | "allow-fqdn-whitelist"
		allowedFqdns?: [...string]

		endpoints: [...{
			name:              string
			protocol:          "http" | "grpc" | "tcp" | "udp" | "tcp-udp"
			tlsMode?:          *"none" | "auto-internal-ca" | "self-signed-upstream"
			containerPort:     int & >=1 & <=65535
			path?:             string
			role:              "ui" | "api" | "management" | "telemetry" | "datastore" | "event-stream" | "generic"
			defaultScope:      "public" | "protected" | "cluster-private" | "telemetry"
			defaultSubdomain?: string
			gatewayTuning?: {
				streaming?:                "none" | "websocket" | "sse" | "grpc-bidi"
				sessionAffinity?:          *"none" | "client-ip" | "cookie-sticky"
				maxBodySizeMb?:            int
				requestHeadersTimeoutSec?: int | *10
				timeoutSeconds?:           int | *30
				rateLimitRps?:             int
				proxyProtocolV2?:          bool
			}
			routes?: [...{
				path:  string
				role:  "ui" | "api" | "management" | "telemetry"
				scope: "public" | "protected" | "cluster-private" | "telemetry"
			}]
		}]

		provides: [...{
			slot:       string
			capability: string
			dialect?:   string
			version:    string

			clientContract?: {
				injectWhenModes: [...string]
				sidecar: {
					name:                   string
					image:                  string
					injectionTarget:        *"k8s-native-init-restart-always" | "standard-container"
					deduplicationScope:     *"per-target-component" | "per-binding"
					portAllocationStrategy: *"deterministic-offset" | "static"
					sharedQuotaFormula?:    string
					settings?: [string]: string | int | bool
					listeners: [...{
						name:          string
						baseLocalPort: int & >=1024 & <=65535
						targetRole:    "primary-rw" | "replicas-ro" | "all-healthy"
					}]
					resources: {
						cpuMillicores: int & <=200
						memoryMb:      int & <=128
					}
					healthcheckIntervalSec: int | *1
					preStopDrainDelaySec:   int | *5
					configTemplate:         string
				}
				exportedTokens: [TokenName=string]: string
			}

			provisioner?: {
				driver:     string
				image:      string
				template?:  string
				scriptRef?: =~"^(passport|topology)://scripts/[a-zA-Z0-9_.-]+$"
				quotas?: [string]:     number | string
				parameters?: [string]: string | int | bool
			}

			onConsumerBindMutations?: {
				setConfig?: [string]: string | int | bool
			}
		}]

		requires: [SlotName=string]: {
			capability:         string
			optional:           bool | *false
			multiBind:          bool | *false
			dependencyStage:    *"infrastructure-ready" | "runtime-parallel"
			versionConstraint?: string
			mountAsFilesPath?:  string
			envMapping: [EnvVar=string]: string
		}
	}

	// 6. Hardware, storage, kernel
	hardwareAndKernel: {
		resources: {
			supportedArchitectures: [...("amd64" | "arm64")] | *["amd64", "arm64"]
			minCpuCores:            number
			minMemoryMb:            int
			recommendedMemoryMb:    int
			ephemeralStorageMb:     int | *2048
			shmSizeMb?:             int
			oomSafetyMarginPercent: int & >=5 & <=50 | *15
			numaTopologyPolicy?:    *"best-effort" | "single-numa-node"
			networkQosClass:        *"realtime-interactive" | "throughput-data" | "background-bulk"
			cpuLimitPolicy:         *"burstable-no-limit" | "hard-cfs-limit"
			verticalScalePolicy?: {
				cpu:    *"in-place" | "pod-restart"
				memory: *"in-place-grow-only" | "pod-restart"
			}
			accelerators?: [...{
				resourceClass: string
				count:         int & >=1
				minMemoryGb?:  int
			}]
			cpuPinning?: "shared" | "exclusive-static"
		}

		storage?: #VolumeSpec
		volumes?: [VolumeName=string]: #VolumeSpec

		kernelTuning?: {
			priority:        int & >=1 & <=1000
			maxClockSkewMs?: int | *50
			kernelModules?: [...string]
			sysctl?: [Param=string]:      #TunableValue
			sysfs?: [Param=string]:       #TunableValue
			ulimits?: [LimitName=string]: int | "unlimited"
		}

		constraints?: {
			incompatiblePassportsOnSameNode?: [...string]
			allowedSecurityZones?: [...string]
			forbiddenConsumerZones?: [...string]
		}
	}

	// 7. Operations
	operations: {
		observability: {
			scrapeEndpoint?:       string
			scrapeInterval:        string | *"30s"
			grafanaDashboardJson?: string
			logPolicy?: {
				maxRateLinesPerSec: int | *1000
				redactPii:          bool | *true
			}
			localAnomalyRules?: [...{
				metric:      string
				algorithm:   "z-score-3sigma" | "linear-regression-disk-full" | "static-threshold"
				threshold?:  string
				forDuration: string | *"5m"
			}]
		}

		backup?: {
			mode:                   *"operator-managed" | "sidecar-stream" | "volume-snapshot-job" | "custom-job"
			driver:                 string
			versionCoupling:        *"match-workload-major" | "pinned"
			targetReplicaRole:      *"prefer-standby" | "primary-only"
			maxUploadBandwidthMbps: int | *250
			retentionDays:          int | *30
			pitrEnabled:            bool | *false
			defaultCron:            string | *"0 2 * * *"
			verifyRestoreJob:       bool | *true
		}

		liveMigration?: {
			supportsExternalReplicaBootstrap: bool
			supportedSources: [...string]
			cutoverWorkflow: {
				maxAllowedLagMs: int | *100
				steps: [...string]
				actionId: string
			}
		}


		day2Actions?: [...{
			id:       string
			title:    string
			category: "first-aid" | "maintenance" | "migration-cutover" | "scaling"
			requiresConfirmation:    bool | *true
			cooldownSeconds:         int | *60
			ttlSecondsAfterFinished: int | *3600
			executionType:           "gitops-patch" | "k8s-job" | "operator-annotation"
			commandOrPatch?:         string
			scriptRef?:              =~"^(passport|topology)://scripts/[a-zA-Z0-9_.-]+$"
		}]
	}
}
