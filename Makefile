#
# Identify environment information
#

ifeq ($(OS),Windows_NT)
	OSName=windows
else ifeq ($(shell uname -s),Darwin)
	OSName=macos
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
	All=clisp ccl ecl sbcl
endif

#
# Set shared variables
#

KernelVersion=20.1

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

RunCLisp=$(ShenCLisp) --clisp-m 32MB
RunCCL=$(ShenCCL)
RunECL=$(ShenECL)
RunSBCL=$(ShenSBCL)

Tests=-e "(do (cd \"kernel/tests\") (load \"README.shen\") (load \"tests.shen\"))"

ReleaseArchiveName=shen-cl-$(GitVersion)-$(OSName)-prebuilt$(ArchiveSuffix)

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
	$(PS) "Invoke-WebRequest -Uri $(KernelArchiveUrl) -OutFile $(KernelArchiveName)"
	$(PS) "Expand-Archive $(KernelArchiveName) -DestinationPath ."
	$(PS) "if (Test-Path $(KernelArchiveName)) { Remove-Item $(KernelArchiveName) -Force }"
	$(PS) "if (Test-Path kernel) { Remove-Item kernel -Recurse -Force }"
	$(PS) "Rename-Item $(KernelFolderName) kernel"
else
	wget $(KernelArchiveUrl)
	tar xf $(KernelArchiveName)
	rm -f $(KernelArchiveName)
	rm -rf kernel
	mv $(KernelFolderName) kernel
endif

#
# Build an implementation
#

.PHONY: build-clisp
build-clisp:
	clisp -i build.lisp

.PHONY: build-ccl
build-ccl:
	ccl -l build.lisp

.PHONY: build-ecl
build-ecl:
	ecl -norc -load build.lisp

.PHONY: build-sbcl
build-sbcl:
	sbcl --load build.lisp

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
# Packging
#

.PHONY: release
release:
ifeq ($(OSName),windows)
	$(PS) "New-Item -Path release -Force -ItemType Directory"
	$(PS) "Compress-Archive -Force -DestinationPath release\\$(ReleaseArchiveName) -LiteralPath $(ShenSBCL), LICENSE.txt"
else
	mkdir -p release
	tar -vczf release/$(ReleaseArchiveName) $(ShenSBCL) LICENSE.txt --transform 's?.*/??g'
endif

#
# Cleanup
#

.PHONY: clean
clean:
ifeq ($(OSName),windows)
	$(PS) "if (Test-Path bin) { Remove-Item bin -Recurse -Force }"
	$(PS) "if (Test-Path release) { Remove-Item release -Recurse -Force }"
else
	rm -rf bin release
endif

.PHONY: pure
pure: clean
ifeq ($(OSName),windows)
	$(PS) "if (Test-Path kernel) { Remove-Item kernel -Recurse -Force }"
else
	rm -rf kernel
endif
