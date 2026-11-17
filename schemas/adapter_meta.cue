// SPDX-License-Identifier: Apache-2.0
// AmiSpec OperatorAdapter meta-schema (normative)
// See docs/design/0033-operator-adapter-ecosystem-and-publisher-ownership.adoc
// and GR-OPR-006/007, GR-CAT-004.
//
// Instance validation:
//   cue vet -d '#OperatorAdapterMeta' schemas/adapter_meta.cue \
//     ../../catalog/adapters/<publisher>/<id>/rev<N>/adapter.meta.yaml

package amispec

// Meta document of an adapter pack (Tier 0 — declarative pack, Design 0033 §3).
#OperatorAdapterMeta: {
	apiVersion: "catalog.amispec.io/v1"
	kind:       "OperatorAdapter"

	metadata: {
		// GR-META-001/002: two-level identity `<publisher>/<id>`; slugs MUST
		// match the path segments (GR-CAT-004).
		publisher: string & =~#"^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$"#
		id:        string & =~#"^[a-z0-9]([a-z0-9-]{0,36}[a-z0-9])?$"# & !~#"-[0-9]+(\.[0-9]+)*$"#
		title:       string & =~#"^[^\s](?:[^\n\r]*[^\s])?$"# & !~#"[\p{Cc}\x{202a}-\x{202e}\x{2066}-\x{2069}]"#
		description: string & =~#"^[^\s](?:[^\n\r]*[^\s])?$"# & !~#"[\p{Cc}\x{202a}-\x{202e}\x{2066}-\x{2069}]"#
		// The adapter's own version (not the operator version — see compatibility).
		version?: string & =~#"^[0-9]+(\.[0-9]+){1,3}(-[A-Za-z0-9.-]+)?$"#
		// Pack revision; MUST match the catalog path `rev<N>` (GR-CAT-004).
		adapterRev: int & >=1
	}

	// The CR family the adapter synthesizes (registry index key,
	// GR-OPR-006: indexed by crdApiVersion/crdKind).
	crd: {
		apiVersion: string
		kind:       string
	}

	compatibility: {
		// Supported operator version range, GR-VER-003 grammar (intervals).
		operatorVersions: string & =~#"^\s*(\*|([<>!=]{1,2}\s*v?[0-9]+(\.[0-9]+){1,3}(-[A-Za-z0-9.-]+)?)(\s+([<>!=]{1,2}\s*v?[0-9]+(\.[0-9]+){1,3}(-[A-Za-z0-9.-]+)?))*)\s*$"#
		// Artifact form is bounded by the publisher tier (GR-OPR-007).
		form: "declarative" | "wasm" | "in-tree"
		tier: "official" | "partner" | "community"
	}
}
