package ghflarebyte

project: {
	org:  "flarebyte"
	repo: "gh-dependency-pulse"
}

sync: {
	mode: "push"
}

repository: {
	branchProtection: {
		enabled: true
		allowAdminCIBypass: true
	}
	description:   "Dependency check and installation across multiple languages"
	defaultBranch: "main"
	homepage:      "https://github.com/flarebyte/gh-dependency-pulse"
	visibility:    "public"
	template:      false
	topics: [
		"gh-extension",
		"github-cli",
		"git",
		"flarebyte",
	]
	labels: [
		{
			name:        "bug"
			color:       "B60205"
			description: "Something is broken"
		},
		{
			name:        "enhancement"
			color:       "0E8A16"
			description: "New feature"
		},
	]
	features: {
		issues:                        true
		wiki:                          false
		projects:                      false
		discussions:                   false
		autoMerge:                     true
		mergeCommit:                   false
		rebaseMerge:                   false
		squashMerge:                   true
		squashMergeCommitMessage:      "pr-title"
		deleteBranchOnMerge:           true
		allowForking:                  false
		allowUpdateBranch:             false
		advancedSecurity:              true
		secretScanning:                true
		secretScanningPushProtection:  true
	}
}

// Build and release become usable once the Go CLI is implemented.
build: {
	mode: "binary"
	language:     "go"
	outputDir:    "build"
	checksumFile: "build/checksums.txt"
	artifactTargetSuffix: true
	targets: [
		"linux-amd64",
		"darwin-arm64",
		"windows-amd64",
	]
}

go: {
	cacheDir: "./.gocache"
	modCacheDir: "./.gomodcache"
	toolchain: "local"
}

release: {
	includeArtifacts: true
	versionSource:    "main.project.yaml"
	tagPrefix:        "v"
	notesMode:        "generate-notes"
	artifactDir:      "build"
	includeChecksums: true
}
