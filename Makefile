KernelVersion=20.1

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
ReleaseName=shen-$(KernelVersion)
NestedFolderName=ShenOSKernel-$(KernelVersion)

ifeq ($(OS),Windows_NT)
	FileName=ShenOSKernel-$(KernelVersion).zip
	BinaryName=shen.exe
	BuildAll=build-clisp build-ccl build-sbcl
	TestAll=test-clisp test-ccl test-sbcl
else
	FileName=ShenOSKernel-$(KernelVersion).tar.gz
	BinaryName=shen
	BuildAll=build-clisp build-ccl build-ecl build-sbcl
	#TestAll=test-clisp test-ccl test-ecl test-sbcl
	# TODO: fix building of ecl and restore testing of it
	TestAll=test-clisp test-ccl test-sbcl
endif

RunCLisp=./native/clisp/$(BinaryName) --clisp-m 10MB
RunCCL=./native/ccl/$(BinaryName)
RunECL=./native/ecl/$(BinaryName)
RunSBCL=./native/sbcl/$(BinaryName)

default: build-test-all

all: fetch build-all test-all

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

build-test-all: build-all test-all

build-all: $(BuildAll)

test-all: $(TestAll)

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
# Build and test an implementation
#

clisp: build-clisp test-clisp

ccl: build-ccl test-ccl

ecl: build-ecl test-ecl

sbcl: build-sbcl test-sbcl

clean:
	rm -rf native

pure: clean
	rm -rf kernel
