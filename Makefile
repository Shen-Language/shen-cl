KernelVersion=20.1

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
ReleaseName=shen-$(KernelVersion)
NestedFolderName=ShenOSKernel-$(KernelVersion)

ifeq ($(OS),Windows_NT)
	FileName=ShenOSKernel-$(KernelVersion).zip
	BinaryName=shen.exe
	# TODO: get ecl working on windows
	#All=clisp ccl ecl sbcl
	All=clisp ccl sbcl
else
	FileName=ShenOSKernel-$(KernelVersion).tar.gz
	BinaryName=shen
	All=clisp ccl ecl sbcl
endif

RunCLisp=./native/clisp/$(BinaryName) --clisp-m 10MB
RunCCL=./native/ccl/$(BinaryName)
RunECL=./native/ecl/$(BinaryName)
RunSBCL=./native/sbcl/$(BinaryName)

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
	powershell.exe -Command "Invoke-WebRequest -Uri $(UrlRoot)/$(ReleaseName)/$(FileName) -OutFile $(FileName)"
	powershell.exe -Command "Expand-Archive $(FileName) -DestinationPath ."
else
	wget $(UrlRoot)/$(ReleaseName)/$(FileName)
	tar xf $(FileName)
endif
	rm -f $(FileName)
	rm -rf kernel
	mv $(NestedFolderName) kernel

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
	$(RunCLisp) -l testsuite.shen

.PHONY: test-ccl
test-ccl: check-tests
	$(RunCCL) -l testsuite.shen

.PHONY: test-ecl
test-ecl: check-tests
	$(RunECL) -l testsuite.shen

.PHONY: test-sbcl
test-sbcl: check-tests
	$(RunSBCL) -l testsuite.shen

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
	rm -rf native

.PHONY: pure
pure: clean
	rm -rf kernel
