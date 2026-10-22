# AmiSpec

**AmiSpec** is an open standard for describing **relationships between
infrastructure entities** (services, datastores, networks, nodes) as typed,
versioned data — so that those systems can be validated, reviewed, and governed
as one connected model instead of isolated manifests.

| Item | Value |
| --- | --- |
| Standard | [docs/specification.adoc](docs/specification.adoc) |
| Meta-schemas | [component_passport.cue](schemas/component_passport.cue), [topology_spec.cue](schemas/topology_spec.cue) |
| Status | Stable Draft · v1.0.0 |
| License | Apache-2.0 |

## Why AmiSpec

Modern clusters are described by dozens of disconnected manifests. Humans cannot
see the whole system; automation cannot check consistency **before** deploy.
AmiSpec defines two related artifacts:

- **`ComponentPassport`** (`catalog.amispec.io/v1`) — a reusable *class* of
  services: availability modes, resource declarations, client-sidecar contracts,
  storage, backup, maintenance hooks.
- **`TopologyBlueprint`** (`topology.amispec.io/v1`) — a concrete *deployment*:
  clusters, nodes, component instances, bindings, external resources,
  multi-cluster links.

From the pair, tooling can:

- validate documents against the meta-schemas;
- reason about **capacity and placement** (node budgets, reserves, commits);
- inject connection sidecars (`clientContract`);
- compile a deterministic manifest tree and decompile it back (Provenance).

The goal is effective **management of infrastructure as a graph of
relationships**, not a particular UI.

## Repository layout

```text
amispec/
├── docs/
│   └── specification.adoc           # Normative spec + user guide
├── schemas/
│   ├── component_passport.cue       # ComponentPassport v1
│   ├── topology_spec.cue            # TopologyBlueprint + CanvasLayout
│   └── schema_test.cue              # Unification assertions
├── tests/
│   ├── valid/                       # Must-pass fixtures
│   ├── invalid/                     # Must-fail fixtures
│   └── goldens/                     # cue export snapshots
├── scripts/
│   ├── test.sh                      # Full suite
│   ├── vet.sh                       # cue vet -d '#Type'
│   ├── negative.sh                  # Invalid must fail
│   └── export-goldens.sh            # Golden check / --update
├── .github/workflows/validate.yml
└── Makefile
```

## Quick start

### Prerequisites

- [CUE CLI](https://cuelang.org) **v0.14+** (CI uses v0.15.0)

```bash
brew install cue
# or: https://github.com/cue-lang/cue/releases
```

### Validate a document

Instances are root-form YAML (`apiVersion` / `kind` / `metadata` at top level).

```bash
./scripts/vet.sh passport path/to/passport.yaml
./scripts/vet.sh topology path/to/topology.yaml
./scripts/vet.sh layout   path/to/canvas.layout.yaml
```

Or with CUE directly:

```bash
cue vet -d '#ComponentPassport' schemas/component_passport.cue app.yaml
cue vet -d '#TopologyBlueprint' schemas/topology_spec.cue schemas/component_passport.cue topo.yaml
```

Silent success means the document is structurally valid.

### Run the full suite

```bash
make test
```

Layers:

1. **Syntax / package** — `cue vet ./schemas/...`
2. **Unit assertions** — `schema_test.cue` unification
3. **Valid fixtures** — `tests/valid/*.yaml` must pass
4. **Negative regression** — `tests/invalid/*.yaml` must fail
5. **Golden snapshots** — `cue export` matches `tests/goldens/`

```bash
make negative          # must-fail only
make goldens           # snapshot check
make goldens-update    # rewrite goldens after intentional schema change
make fmt               # format CUE
```

## Minimal example

Passport (see `tests/valid/passport-minimal.yaml`):

```yaml
apiVersion: catalog.amispec.io/v1
kind: ComponentPassport
metadata:
  id: demo-worker
  name: Demo Queue Worker
  version: 1.0.0
  passportRev: 1
  category: application
  archetype: stateless-app
  distribution:
    tier: open-core
    license: Apache-2.0
# … topologyModes, workload, interfaces, hardwareAndKernel, operations
```

Topology (see `tests/valid/topology-minimal.yaml`):

```yaml
apiVersion: topology.amispec.io/v1
kind: TopologyBlueprint
metadata:
  projectId: demo-blog
  organization: example-org
  gitMode: managed-embedded
clusters:
  - id: local
    name: Demo Cluster
    domain: example.local
    # … security, cni, nodes, components, bindings
```

## Core concepts

| Term | Meaning |
| --- | --- |
| ComponentPassport | Reusable service class (HA, formulas, sidecars) |
| TopologyBlueprint | Concrete deployment (clusters, nodes, bindings) |
| passportRev | Version of passport *rules*, not software version |
| Slot / Requirement | Provider capability and consumer need |
| Binding | Graph edge: consumer → provider slot |
| clientContract | Provider dictates local proxy sidecar on `127.0.0.1` |
| Capacity model | Node budgets, reserves (`systemReservedMb`, `committed*`) for placement |
| CanvasLayout | Optional layout coordinates for visualization tools |

Normative definitions: [docs/specification.adoc](docs/specification.adoc) § Terms.

## Capacity and placement

The schema always records **fixed resource facts** (CPU, memory, disk, reserves)
so that tooling can place workloads on nodes with available capacity. Example
fields: `resources.memoryMb`, `nodes[].hardware`, `systemReservedMb`,
`committedReplicas`, `committedSizeGb`, `diskExclusive`, `quotaCpuCores`.

These are part of the open data model. Higher-level schedulers and capacity
planning tools can consume them without being part of the standard itself.

## Conformance

| Artifact | Check |
| --- | --- |
| Passport | Valid `#ComponentPassport`, required blocks filled |
| Topology | Valid `#TopologyBlueprint`, bindings resolve, capacity fields consistent |
| Compiler | Deterministic compile, Provenance, lossless decompile (Level A) |

Fixtures in `tests/` are the recommended **conformance test set**.

## Schema stability

- Meta-schemas are **normative**; examples in the spec are informative.
- Breaking schema changes bump the standard version and update goldens.
- `passportRev` pins consumer deployments against silent catalog drift.

## Development

```bash
vim schemas/topology_spec.cue
make test
make goldens-update   # only when render drift is intended
```

CI (`.github/workflows/validate.yml`) runs the same gates on schema/test changes.

## Documentation

| Document | Role |
| --- | --- |
| [specification](docs/specification.adoc) | Spec + layered user guide |
| [component_passport.cue](schemas/component_passport.cue) | Passport meta-schema |
| [topology_spec.cue](schemas/topology_spec.cue) | Topology meta-schema |

```bash
asciidoctor -b html5 docs/specification.adoc
```

Implementation libraries (validator / compiler) live in the companion repository
[amispec-core](https://github.com/amiterra/amispec-core).

## License

Apache License 2.0. Normative content: CUE meta-schemas and normative clauses of
`docs/specification.adoc` (Scope, Normative References, Terms, Conformance,
invariants). Reference examples and checklists are informative.
