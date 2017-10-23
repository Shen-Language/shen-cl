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

RunCLisp=./bin/clisp/$(BinaryName) --clisp-m 10MB
RunCCL=./bin/ccl/$(BinaryName)
RunECL=./bin/ecl/$(BinaryName)
RunSBCL=./bin/sbcl/$(BinaryName)

Tests=-e "(do (cd \"kernel/tests\") (load \"README.shen\") (load \"tests.shen\"))"

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

.PHONY: check-klambda
.SILENT: check-klambda
check-klambda:
	[ -d ./kernel/klambda ] || { \
	echo ""; \
	echo "Directory './kernel/klambda' not found."; \
	echo "Run 'make fetch' to retrieve Shen Kernel sources."; \
	echo ""; \
	exit 1; \
	}

.PHONY: check-tests
.SILENT: check-tests
check-tests:
	[ -d ./kernel/tests ] || { \
	echo ""; \
	echo "Directory './kernel/tests' not found."; \
	echo "Run 'make fetch' to retrieve Shen Kernel sources."; \
	echo ""; \
	exit 1; \
	}

#
# Build an implementation
#

.PHONY: build-clisp
build-clisp: check-klambda
	clisp -i install.lsp

.PHONY: build-ccl
build-ccl: check-klambda
	ccl -l install.lsp

.PHONY: build-ecl
build-ecl: check-klambda
	ecl -norc -load install.lsp

.PHONY: build-sbcl
build-sbcl: check-klambda
	sbcl --load install.lsp

#
# Test an implementation
#

.PHONY: test-clisp
test-clisp: check-tests
	$(RunCLisp) $(Tests)

.PHONY: test-ccl
test-ccl: check-tests
	$(RunCCL) $(Tests)

.PHONY: test-ecl
test-ecl: check-tests
	$(RunECL) $(Tests)

.PHONY: test-sbcl
test-sbcl: check-tests
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
# Cleanup
#

.PHONY: clean
clean:
	rm -rf bin

.PHONY: pure
pure: clean
	rm -rf kernel
