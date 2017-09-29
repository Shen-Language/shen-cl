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

default: all

#
# Aggregates
#

all: $(All)

clisp: build-clisp test-clisp

ccl: build-ccl test-ccl

ecl: build-ecl test-ecl

sbcl: build-sbcl test-sbcl

#
# Dependency retrieval
#

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

check-klambda:
	@[ -d ./kernel/klambda ] || { \
	echo ""; \
	echo "Directory './kernel/klambda' not found."; \
	echo "Run 'make fetch' to retrieve Shen Kernel sources."; \
	echo ""; \
	exit 1; \
	}

check-tests:
	@[ -d ./kernel/tests ] || { \
	echo ""; \
	echo "Directory './kernel/tests' not found."; \
	echo "Run 'make fetch' to retrieve Shen Kernel sources."; \
	echo ""; \
	exit 1; \
	}

#
# Build an implementation
#

build-clisp: check-klambda
	clisp -i install.lsp

build-ccl: check-klambda
	ccl -l install.lsp

build-ecl: check-klambda
	ecl -norc -load install.lsp

build-sbcl: check-klambda
	sbcl --load install.lsp

#
# Test an implementation
#

test-clisp: check-tests
	$(RunCLisp) -l testsuite.shen

test-ccl: check-tests
	$(RunCCL) -l testsuite.shen

test-ecl: check-tests
	$(RunECL) -l testsuite.shen

test-sbcl: check-tests
	$(RunSBCL) -l testsuite.shen

#
# Run an implementation
#

run-clisp:
	$(RunCLisp) $(Args)

run-ccl:
	$(RunCCL) $(Args)

run-ecl:
	$(RunECL) $(Args)

run-sbcl:
	$(RunSBCL) $(Args)

#
# Cleanup
#

clean:
	rm -rf native

pure: clean
	rm -rf kernel
