#
# Identify environment information
#

FetchCmd=wget

ifeq ($(OS),Windows_NT)
	OSName=windows
else ifeq ($(shell uname -s),Darwin)
	OSName=macos
	FetchCmd=curl -OL
else ifeq ($(shell uname -s),FreeBSD)
	OSName=freebsd
	FetchCmd=/usr/bin/fetch
else ifeq ($(shell uname -s),OpenBSD)
	OSName=openbsd
	FetchCmd=/usr/bin/ftp
else ifeq ($(shell uname -s),NetBSD)
	OSName=netbsd
	FetchCmd=/usr/bin/ftp -o $(KernelArchiveName)
else
	OSName=linux
endif

GitVersion=$(shell git tag -l --contains HEAD)

ifeq ("$(GitVersion)","")
	GitVersion=$(shell git rev-parse --short HEAD)
endif

#
# Set OS-specific variables
#

ifeq ($(OSName),windows)
	Slash=\\\\
	ArchiveSuffix=.zip
	BinarySuffix=.exe
	All=clisp ccl sbcl
	PS=powershell.exe -Command
else
	Slash=/
	ArchiveSuffix=.tar.gz
	BinarySuffix=
	All=ccl ecl sbcl
	ifeq ($(OSName),freebsd)
		All=ccl ecl sbcl
	else ifeq ($(OSName),openbsd)
		All=ecl sbcl
	else ifeq ($(OSName),netbsd)
		All=clisp ecl
	endif
endif

CCL=ccl
CLISP=clisp
ECL=ecl
SBCL=sbcl

ifeq ($(OS_NAME),windows)
	SBCL="$(WINDOWS_SBCL_PATH)/sbcl.exe" --core "$(WINDOWS_SBCL_PATH)/sbcl.core"
endif

#
# Set shared variables
#

KernelVersion=22.3

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
KernelTag=shen-$(KernelVersion)
KernelFolderName=ShenOSKernel-$(KernelVersion)
KernelArchiveName=$(KernelFolderName)$(ArchiveSuffix)
KernelArchiveUrl=$(UrlRoot)/$(KernelTag)/$(KernelArchiveName)
BinaryName=shen$(BinarySuffix)

ShenCLisp=.$(Slash)bin$(Slash)clisp$(Slash)$(BinaryName)
ShenCCL=.$(Slash)bin$(Slash)ccl$(Slash)$(BinaryName)
ShenECL=.$(Slash)bin$(Slash)ecl$(Slash)$(BinaryName)
ShenSBCL=.$(Slash)bin$(Slash)sbcl$(Slash)$(BinaryName)

RunCLisp=$(ShenCLisp) --clisp-m 10MB
RunCCL=$(ShenCCL)
RunECL=$(ShenECL)
RunSBCL=$(ShenSBCL)

Tests=eval -e "(cd \"kernel/tests\")" -l README.shen -l tests.shen

ReleaseArchiveName=shen-cl-$(GitVersion)-$(OSName)-prebuilt$(ArchiveSuffix)
SourceReleaseName=shen-cl-$(GitVersion)-sources

#
# Aggregates and defaults
#

.DEFAULT: all
.PHONY: all
all: $(All)

.PHONY: clisp
clisp: build-clisp test-clisp

.PHONY: ccl
ccl: build-ccl test-ccl

.PHONY: ecl
ecl: build-ecl test-ecl

.PHONY: sbcl
sbcl: build-sbcl test-sbcl

.PHONY: run
run: run-sbcl

#
# Dependency retrieval
#

.PHONY: fetch
fetch:
ifeq ($(OSName),windows)
	$(PS) "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
	       Invoke-WebRequest -Uri $(KernelArchiveUrl) -OutFile $(KernelArchiveName)"
	$(PS) "Expand-Archive $(KernelArchiveName) -DestinationPath ."
	$(PS) "if (Test-Path $(KernelArchiveName)) { Remove-Item $(KernelArchiveName) -Force -ErrorAction Ignore }"
	$(PS) "if (Test-Path kernel) { Remove-Item kernel -Recurse -Force -ErrorAction Ignore }"
	$(PS) "Rename-Item $(KernelFolderName) kernel -ErrorAction Ignore"
else
	$(FetchCmd) $(KernelArchiveUrl)
	tar zxf $(KernelArchiveName)
	rm -f $(KernelArchiveName)
	rm -rf kernel
	mv $(KernelFolderName) kernel
endif

#
# Precompilation into Lisp code
#

.PHONY: precompile
precompile:
ifndef SHEN
	$(info Usage: make precompile SHEN=path/to/shen.exe)
	$(error SHEN variable is not defined)
else
	mkdir -p compiled
	$(SHEN) eval -l scripts/build.shen -e "(build)"
endif

#
# Build an implementation
#

.PHONY: build-clisp
build-clisp:
	$(CLISP) -i boot.lsp

.PHONY: build-ccl
build-ccl:
	$(CCL) -l boot.lsp

.PHONY: build-ecl
build-ecl:
	$(ECL) -norc -load boot.lsp

.PHONY: build-sbcl
build-sbcl:
	$(SBCL) --load boot.lsp

#
# Test an implementation
#

.PHONY: test-clisp
test-clisp:
	$(RunCLisp) $(Tests)

.PHONY: test-ccl
test-ccl:
	$(RunCCL) $(Tests)

.PHONY: test-ecl
test-ecl:
	$(RunECL) $(Tests)

.PHONY: test-sbcl
test-sbcl:
	$(RunSBCL) $(Tests)

#
# Run an implementation
#

.PHONY: run-clisp
run-clisp:
	$(RunCLisp) $(Args)

.PHONY: run-ccl
run-ccl:
	$(RunCCL) $(Args)

.PHONY: run-ecl
run-ecl:
	$(RunECL) $(Args)

.PHONY: run-sbcl
run-sbcl:
	$(RunSBCL) $(Args)

#
# Packaging
#

.PHONY: release
release:
ifeq ($(OSName),windows)
	$(PS) "New-Item -Path release -Force -ItemType Directory"
	$(PS) "Compress-Archive -Force -DestinationPath release\\$(ReleaseArchiveName) -LiteralPath $(ShenSBCL), LICENSE.txt"
else ifeq ($(OSName),linux)
	mkdir -p release
	tar -vczf release/$(ReleaseArchiveName) $(ShenSBCL) LICENSE.txt --transform 's?.*/??g'
else
	mkdir -p release
	tar -vczf release/$(ReleaseArchiveName) -s '?.*/??g' $(ShenSBCL) LICENSE.txt
endif

.PHONY: source-release
source-release:
ifeq ($(OSName),windows)
	$(PS) "New-Item -Path release -Force -ItemType Directory"
	$(PS) "New-Item -Path release\\$(SourceReleaseName) -Force -ItemType Directory"
	$(PS) "Copy-Item -Path src, compiled, scripts, tests, assets, Makefile, boot.lsp, LICENSE.txt, README.md, CHANGELOG.md, INTEROP.md, PREREQUISITES.md -Recurse -Destination release\\$(SourceReleaseName)"
	$(PS) "cd release; Compress-Archive -Force -DestinationPath $(SourceReleaseName)$(ArchiveSuffix) -LiteralPath $(SourceReleaseName)"
	$(PS) "Remove-Item -LiteralPath release\\$(SourceReleaseName) -Force -Recurse"
else ifeq ($(OSName),linux)
	mkdir -p release
	tar -vczf release/$(SourceReleaseName)$(ArchiveSuffix) src compiled scripts tests assets Makefile boot.lsp LICENSE.txt README.md CHANGELOG.md INTEROP.md PREREQUISITES.md --transform "s?^?$(SourceReleaseName)/?g"
else
	mkdir -p release
	tar -vczf release/$(SourceReleaseName)$(ArchiveSuffix) -s "?^?$(SourceReleaseName)/?g" src compiled scripts tests assets Makefile boot.lsp LICENSE.txt README.md CHANGELOG.md INTEROP.md PREREQUISITES.md
endif

#
# Cleanup
#

.PHONY: clean
clean:
ifeq ($(OSName),windows)
	$(PS) "if (Test-Path bin) { Remove-Item bin -Recurse -Force -ErrorAction Ignore }"
	$(PS) "if (Test-Path release) { Remove-Item release -Recurse -Force -ErrorAction Ignore }"
else
	rm -rf bin release
endif

.PHONY: pure
pure: clean
ifeq ($(OSName),windows)
	$(PS) "if (Test-Path kernel) { Remove-Item kernel -Recurse -Force -ErrorAction Ignore }"
else
	rm -rf kernel
endif
