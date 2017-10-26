KernelVersion=20.1

ifeq ($(OS),Windows_NT)
	ArchiveSuffix=.zip
	BinarySuffix=.exe
	All=clisp ccl sbcl
else
	ArchiveSuffix=.tar.gz
	BinarySuffix=
	All=clisp ccl ecl sbcl
endif

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
ReleaseName=shen-$(KernelVersion)
ArchiveFolderName=ShenOSKernel-$(KernelVersion)
ArchiveName=$(ArchiveFolderName)$(ArchiveSuffix)
BinaryName=shen$(BinarySuffix)

ShenClisp=./bin/clisp/$(BinaryName)
ShenCCL=./bin/ccl/$(BinaryName)
ShenECL=./bin/ecl/$(BinaryName)
ShenSBCL=./bin/sbcl/$(BinaryName)

RunCLisp=$(ShenCLisp) --clisp-m 10MB
RunCCL=$(ShenCCL)
RunECL=$(ShenECL)
RunSBCL=$(ShenSBCL)

BootFile=boot.lsp
LicenseFile=LICENSE.txt

Tests=-e "(do (cd \"kernel/tests\") (load \"README.shen\") (load \"tests.shen\"))"

GitVersion=$(shell git tag -l --contains HEAD)

ifeq ("$(GitVersion)","")
	GitVersion=$(shell git rev-parse --short HEAD)
endif

#
# Aggregates
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

#
# Dependency retrieval
#

.PHONY: fetch
fetch:
ifeq ($(OS),Windows_NT)
	powershell.exe -Command "Invoke-WebRequest -Uri $(UrlRoot)/$(ReleaseName)/$(ArchiveName) -OutFile $(ArchiveName)"
	powershell.exe -Command "Expand-Archive $(ArchiveName) -DestinationPath ."
else
	wget $(UrlRoot)/$(ReleaseName)/$(ArchiveName)
	tar xf $(ArchiveName)
endif
	rm -f $(ArchiveName)
	rm -rf kernel
	mv $(ArchiveFolderName) kernel

#
# Build an implementation
#

.PHONY: build-clisp
build-clisp:
	clisp -i $(BootFile)

.PHONY: build-ccl
build-ccl:
	ccl -l $(BootFile)

.PHONY: build-ecl
build-ecl:
	ecl -norc -load $(BootFile)

.PHONY: build-sbcl
build-sbcl:
	sbcl --load $(BootFile)

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

.PHONY: archive
archive:
ifeq ($(OS),Windows_NT)
	powershell.exe -Command "New-Item -Force -ItemType Directory -Path .\\dist"
	powershell.exe -Command "Compress-Archive -Force -DestinationPath .\\dist\\shen-cl-windows-prebuilt-$(GitVersion)$(ArchiveSuffix) -LiteralPath $(ShenSBCL), $(LicenseFile)"
else ifeq ($(shell uname -s),Darwin)
	mkdir -p dist
	tar -vczf ./dist/shen-cl-macos-prebuilt-$(GitVersion)$(ArchiveSuffix) $(ShenSBCL) $(LicenseFile) --transform 's?.*/??g'
else
	mkdir -p dist
	tar -vczf ./dist/shen-cl-linux-prebuilt-$(GitVersion)$(ArchiveSuffix) $(ShenSBCL) $(LicenseFile) --transform 's?.*/??g'
endif

#
# Cleanup
#

.PHONY: clean
clean:
	rm -rf bin dist

.PHONY: pure
pure: clean
	rm -rf kernel
