// SPDX-License-Identifier: Apache-2.0
// AmiSpec ComponentPassport meta-schema (normative)
// See docs/specification.adoc — Part III, ComponentPassport v1
// apiVersion: catalog.amispec.io/v1
//
// Standalone package `amispec` (CUE). Validates ComponentPassport documents.

package amispec

import "strings"

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
	initialDelaySeconds?: int & >=0
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
		mountFlags: [...#MountFlag] | *["noatime", "nodiratime"]
		filesystem:         *"xfs" | "ext4"
		emergencyBallastMb: int | *1024
	}
}

#ComponentPassport: {
	apiVersion: "catalog.amispec.io/v1"
	kind:       "ComponentPassport"

	// 1. Metadata, distribution, visualization
	// Field requirements: docs/components/catalog/schema-golden-requirements.adoc
	// (GR-META-001/002/003/007/008, GR-VER-001/002). CUE is the normative schema;
	// `amispec-validate` mirrors it and both are contract-tested on shared fixtures.
	metadata: {
		// GR-META-001/002: two-level identity `<publisher>/<id>`, slug grammar,
		// edges alphanumeric, `--` allowed, no dots/underscores; length 1..32 / 1..40.
		publisher: string & =~#"^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$"#
		id:        string & =~#"^[a-z0-9]([a-z0-9-]{0,36}[a-z0-9])?$"# & !~#"-[0-9]+(\.[0-9]+)*$"# // GR-META-003: no version suffix
		// GR-META-007: display title — single line, trimmed, no control/bidi, 1..80 runes.
		title:       string & =~#"^[^\s](?:[^\n\r]*[^\s])?$"# & !~#"[\p{Cc}\x{202a}-\x{202e}\x{2066}-\x{2069}]"#
		_titleRunes: len(strings.Runes(title)) & >=1 & <=80
		// GR-META-008: product signature — single line, trimmed, no control/bidi, 1..300 runes.
		description:       string & =~#"^[^\s](?:[^\n\r]*[^\s])?$"# & !~#"[\p{Cc}\x{202a}-\x{202e}\x{2066}-\x{2069}]"#
		_descriptionRunes: len(strings.Runes(description)) & >=1 & <=300
		// GR-VER-001/002: optional (derivable from a version-ful image tag);
		// format 2-4 numeric segments + optional suffix.
		version?:    string & =~#"^[0-9]+(\.[0-9]+){1,3}(-[A-Za-z0-9.-]+)?$"#
		passportRev: int & >=1
		category:    "database" | "analytics" | "cache" | "message-queue" | "application" | "ai-ml" | "gateway" | "observability" | "storage" | "security" | "external"
		archetype:   "stateless-app" | "stateful-service" | "operator-cluster" | "edge-gateway" | "external-bridge" | "scheduled-job"

		distribution: {
			tier: *"open-core" | "private-custom" // MVP: open vs private passport
			// GR-META-011: SPDX id or expression (ids combined with OR/AND/WITH).
			license: string & =~#"^[A-Za-z0-9.()+-]+( (OR|AND|WITH) [A-Za-z0-9.()+-]+)*$"# | *"Apache-2.0"
			vendor?: {
				name:               string
				requiresLicenseKey: bool | *false
			}
		}

		canvasUI: {
			// GR-META-012: console icon set is keyed by kebab slug.
			icon:        string & =~#"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"#
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
			// Container name inside the pod (default `app`).
			name?:        string
			image: string
			// GR-IMG-001: every image is a canonical ref + mandatory digest
			// (multi-arch index digest; label-safe pin budget is GR-PIN-002).
			imageDigest:            =~#"^sha256:[a-f0-9]{64}$"#
			pullSecretRequired:     bool | *false
			readOnlyRootFilesystem: bool | *true
			// Pod-level fields (runAs*/fsGroup/seccompProfile) materialize in
			// `pod.spec.securityContext`; container-level fields
			// (allowPrivilegeEscalation/capabilitiesDrop) in the container's.
			securityContext?: {
				runAsNonRoot:             bool | *true
				runAsUser:                int | *10001
				runAsGroup?:              int
				fsGroup:                  int | *10001
				seccompProfile?:          "RuntimeDefault" | "Unconfined" | "Localhost"
				allowPrivilegeEscalation?: bool
				capabilitiesDrop?: [...string]
			}
			command?: [...string]
			args?: [...string]
			// Static/derived container env (fieldRef, secretKeyRef, literals).
			// Secret VALUES never appear — only Secret names (ADR-0009).
			env?: [...{
				name: string
				value?: string
				valueFrom?: {
					fieldRef?: {fieldPath: string}
					secretKeyRef?: {name: string, key: string}
				}
			}]
			// Container ports (contract endpoints declare the EXPOSED subset;
			// this list is the full container port inventory).
			ports?: [...{
				name:          string
				containerPort: int & >=1 & <=65535
			}]
			zeroEndpoints: bool | *false
		}

		companions?: [...{
			name:        string
			image:       string
			imageDigest: =~#"^sha256:[a-f0-9]{64}$"#
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
			// GR-OPR-006: the adapter pack that supplies this operator and maps
			// the CR (`<publisher>/<id>@rev<N>`). Explicit passport↔adapter link.
			adapter:           string & =~#"^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?/[a-z0-9]([a-z0-9-]{0,36}[a-z0-9])?@rev[1-9][0-9]*$"#
			// Legacy inline CR template; superseded by the adapter pack.
			manifestTemplate?: string
		}

		configFormulas?: [ParamName=string]: {
			cel:         string
			unit?:       "MB" | "GB" | "bytes" | "count" | "string"
			targetPath:  string
			applyImpact: *"hot-reload" | "rolling-switchover" | "pod-restart"
			description: string
		}

		// Workload config mounts. `name` is the pod volume name; the source is
		// a script ConfigMap (`fromSecret: false`, named `<component>-<name>`)
		// or a Secret (`fromSecret: true`, name = `source`, `$params.<k>` token).
		configMounts?: [...{
			name:           string
			mountPath:      string
			subPath?:       string
			fromSecret:     bool | *true
			source?:        string
			items?: [...{key: string, path?: string}]
			readOnly?:      bool | *true
			defaultMode?:   int
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
			// GR-VER-001: optional, defaults to metadata.version (enforced downstream).
			version?: string & =~#"^[0-9]+(\.[0-9]+){1,3}(-[A-Za-z0-9.-]+)?$"#
			// GR-CRED-002: fulfillment declaration; grant vocabulary is owned by
			// the capability contract, so verbs stay free strings here.
			access?: {
				fulfillment?: [...string]
				columnLevel?: bool
				plugins?: [...string]
			}

			clientContract?: {
				injectWhenModes?: [...string]
				sidecar?: {
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
				// Non-secret export surface (hostnames, buckets, regions).
				// Values: literals or `$params.<key>` (the provider's own
				// parameters). Materialized as ConfigMap `<component>-endpoint`.
				exportedTokens?: [TokenName=string]: string
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
			capability:      string
			optional:        bool | *false
			multiBind:       bool | *false
			dependencyStage: *"infrastructure-ready" | "runtime-parallel"
			// GR-VER-003: comparators `= != > >= < <=` AND-ed by spaces; `*` = any.
			version?:          string & =~#"^\s*(\*|([<>!=]{1,2}\s*v?[0-9]+(\.[0-9]+){1,3}(-[A-Za-z0-9.-]+)?)(\s+([<>!=]{1,2}\s*v?[0-9]+(\.[0-9]+){1,3}(-[A-Za-z0-9.-]+)?))*)\s*$"#
			mountAsFilesPath?: string
			// Consumer env for processes using this slot. A flat string applies
			// to every using process; a per-process map scopes the value to the
			// named process (deploy vs runtime traffic may need different
			// endpoints/credentials — e.g. `$names.rw` for migrations vs
			// `$names.pooler` for runtime).
			envMapping: [EnvVar=string]: string | {[ProcessName=string]: string}
		}
	}

	// 5b. Credential processes: process -> access contract (GR-CRED-001..005).
	// Process names belong to the application; the grant vocabulary is owned by
	// the capability contract, so verbs/resources stay free strings here.
	// Dangerous escalations are forbidden platform-wide (GR-CRED-003).
	processes?: [ProcessName=string]: {
		// "deploy" marks the migration/deploy process; `ddl` grants require it.
		role?: "deploy" | "runtime"
		uses: [...{
			slot: string
			grants: [...{
				verbs: [...string & !~#"(?i)^(superuser|createrole|replication)$"#]
				resources: [...string]
			}]
			plugins?: [...string]
		}]
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
			id:                      string
			title:                   string
			category:                "first-aid" | "maintenance" | "migration-cutover" | "scaling"
			requiresConfirmation:    bool | *true
			cooldownSeconds:         int | *60
			ttlSecondsAfterFinished: int | *3600
			executionType:           "gitops-patch" | "k8s-job" | "operator-annotation"
			commandOrPatch?:         string
			scriptRef?:              =~"^(passport|topology)://scripts/[a-zA-Z0-9_.-]+$"
		}]
	}
}
