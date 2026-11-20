package ghflarebyte

project: {
	org:  "flarebyte"
	repo: "gh-dependency-pulse"
}

sync: {
	mode: "push"
}

repository: {
	// Require PRs and the Actions "CI passed" check; block force pushes and deletion.
	branchProtection: {
		enabled:            true
		allowAdminCIBypass: true // Admin CI bypass applies through PRs only.
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
			color:      "d73a4a"
			description: "Something isn't working"
			name:       "bug"
		},
		{
			color:      "0075ca"
			description: "Improvements or additions to documentation"
			name:       "documentation"
		},
		{
			color:      "cfd3d7"
			description: "This issue or pull request already exists"
			name:       "duplicate"
		},
		{
			color:      "a2eeef"
			description: "New feature or request"
			name:       "enhancement"
		},
		{
			color:      "7057ff"
			description: "Good for newcomers"
			name:       "good first issue"
		},
		{
			color:      "008672"
			description: "Extra attention is needed"
			name:       "help wanted"
		},
		{
			color:      "e4e669"
			description: "This doesn't seem right"
			name:       "invalid"
		},
		{
			color:      "d876e3"
			description: "Further information is requested"
			name:       "question"
		},
		{
			color:      "ffffff"
			description: "This will not be worked on"
			name:       "wontfix"
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

// Build the development CLI skeleton; package operations remain unimplemented.
build: {
	mainPackage: "./cmd/gh-dependency-pulse"
	mode:                "binary"
	language:            "go"
	outputDir:           "build"
	checksumFile:        "build/checksums.txt"
	artifactTargetSuffix: true
	targets: [
		"linux-amd64",
		"darwin-arm64",
		"windows-amd64",
	]
}

go: {
	cacheDir:   "./.gocache"
	modCacheDir: "./.gomodcache"
	toolchain:  "local"
}

release: {
	includeArtifacts: true
	versionSource:   "main.project.yaml"
	tagPrefix:       "v"
	notesMode:       "generate-notes"
	artifactDir:     "build"
	includeChecksums: true
}
