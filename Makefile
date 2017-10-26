KernelVersion=20.1

ifeq ($(OS),Windows_NT)
	ArchiveSuffix=.zip
	BinarySuffix=.exe
	All=clisp ccl sbcl

	ShenClisp=.\\bin\\clisp\\$(BinaryName)
	ShenCCL=.\\bin\\ccl\\$(BinaryName)
	ShenECL=.\\bin\\ecl\\$(BinaryName)
	ShenSBCL=.\\bin\\sbcl\\$(BinaryName)
else
	ArchiveSuffix=.tar.gz
	BinarySuffix=
	All=clisp ccl ecl sbcl

	ShenClisp=./bin/clisp/$(BinaryName)
	ShenCCL=./bin/ccl/$(BinaryName)
	ShenECL=./bin/ecl/$(BinaryName)
	ShenSBCL=./bin/sbcl/$(BinaryName)
endif

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
ReleaseName=shen-$(KernelVersion)
ArchiveFolderName=ShenOSKernel-$(KernelVersion)
ArchiveName=$(ArchiveFolderName)$(ArchiveSuffix)
BinaryName=shen$(BinarySuffix)

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

PS=powershell.exe -Command

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
	$(PS) "Invoke-WebRequest -Uri $(UrlRoot)/$(ReleaseName)/$(ArchiveName) -OutFile $(ArchiveName)"
	$(PS) "Expand-Archive $(ArchiveName) -DestinationPath ."
	$(PS) "if (Test-Path $(ArchiveName)) { Remove-Item $(ArchiveName) -Force -ErrorAction Ignore }"
	$(PS) "if (Test-Path kernel) { Remove-Item kernel -Recurse -Force -ErrorAction Ignore }"
	$(PS) "Rename-Item $(ArchiveFolderName) kernel -ErrorAction Ignore"
else
	wget $(UrlRoot)/$(ReleaseName)/$(ArchiveName)
	tar xf $(ArchiveName)
	rm -f $(ArchiveName)
	rm -rf kernel
	mv $(ArchiveFolderName) kernel
endif

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

.PHONY: release
release:
ifeq ($(OS),Windows_NT)
	$(PS) "New-Item -Path release -Force -ItemType Directory"
	$(PS) "Compress-Archive -Force -DestinationPath release\\shen-cl-windows-prebuilt-$(GitVersion)$(ArchiveSuffix) -LiteralPath $(ShenSBCL), $(LicenseFile)"
else ifeq ($(shell uname -s),Darwin)
	mkdir -p release
	tar -vczf release/shen-cl-macos-prebuilt-$(GitVersion)$(ArchiveSuffix) $(ShenSBCL) $(LicenseFile) --transform 's?.*/??g'
else
	mkdir -p release
	tar -vczf release/shen-cl-linux-prebuilt-$(GitVersion)$(ArchiveSuffix) $(ShenSBCL) $(LicenseFile) --transform 's?.*/??g'
endif

#
# Cleanup
#

.PHONY: clean
clean:
ifeq ($(OS),Windows_NT)
	$(PS) "if (Test-Path bin) { Remove-Item bin -Recurse -Force -ErrorAction Ignore }"
	$(PS) "if (Test-Path release) { Remove-Item release -Recurse -Force -ErrorAction Ignore }"
else
	rm -rf bin release
endif

.PHONY: pure
pure: clean
ifeq ($(OS),Windows_NT)
	$(PS) "if (Test-Path kernel) { Remove-Item kernel -Recurse -Force -ErrorAction Ignore }"
else
	rm -rf kernel
endif
