GITREF=$(shell git describe --long --tags)

# $(VERSION_GO) will be written to version.go
VERSION_GO="// Code generated by \"make version\". DO NOT EDIT.\n\
package teleport\n\n\
const Version = \"$(VERSION)\"\n\n\
// Gitref is set to the output of \"git describe\" during the build process.\n\
var Gitref string\n"

# $(API_VERSION_GO) will be written to api/version.go
API_VERSION_GO="// Code generated by \"make version\". DO NOT EDIT.\n\
package api\n\n\
const Version = \"$(VERSION)\"\n\n\
// Gitref is set to the output of \"git describe\" during the build process.\n\
var Gitref string\n"

# $(UPDATER_VERSION_GO) will be written to api/version.go
UPDATER_VERSION_GO="// Code generated by \"make version\". DO NOT EDIT.\n\
package kubeversionupdater\n\n\
const Version = \"$(VERSION)\"\n\n\
// Gitref is set to the output of \"git describe\" during the build process.\n\
var Gitref string\n"

# $(GITREF_GO) will be written to gitref.go
GITREF_GO="// Code generated by \"make version\". DO NOT EDIT.\n\
package teleport\n\n\
func init() { Gitref = \"$(GITREF)\" }\n"

#
# setver updates version.go and gitref.go with VERSION and GITREF vars
#
.PHONY:setver
setver: validate-semver helm-version tsh-version
	@printf $(VERSION_GO) | gofmt > version.go
	@printf $(API_VERSION_GO) | gofmt > ./api/version.go
	@printf $(UPDATER_VERSION_GO) | gofmt > ./integrations/kube-agent-updater/version.go
	@printf $(GITREF_GO) | gofmt > gitref.go

# helm-version automatically updates the versions of Helm charts to match the version set in the Makefile,
# so that chart versions are also kept in sync when the Teleport version is updated for a release.
# If the version contains '-dev' (as it does on the master branch, or for development builds) then we get the latest
# published major version number by parsing a sorted list of git tags instead, to make deploying the chart from master
# work as expected. Version numbers are quoted as a string because Helm otherwise treats dotted decimals as floats.
# The weird -i usage is to make the sed commands work the same on both Linux and Mac. Test on both platforms if you change it.
.PHONY:helm-version
helm-version:
	for CHART in teleport-cluster teleport-kube-agent teleport-cluster/charts/teleport-operator; do \
		sed -i'.bak' -e "s_^\\.version:\ .*_.version: \\&version \"$${VERSION}\"_g" examples/chart/$${CHART}/Chart.yaml || exit 1; \
		rm -f examples/chart/$${CHART}/Chart.yaml.bak; \
	done

TSH_APP_PLISTS := $(wildcard build.assets/macos/*/tsh.app/Contents/Info.plist)
PLIST_FILES := $(abspath $(TSH_APP_PLISTS))

# tsh-version sets CFBundleVersion and CFBundleShortVersionString in the tsh{,dev} Info.plist
.PHONY:tsh-version
tsh-version:
	cd build.assets/tooling && go run ./cmd/update-plist-version $(VERSION) $(PLIST_FILES)

.PHONY:validate-semver
validate-semver:
	cd build.assets/tooling && CGO_ENABLED=0 go run ./cmd/check -check valid -tag v$(VERSION)
