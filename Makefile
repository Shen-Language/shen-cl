KernelVersion=20.0

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
ReleaseName=shen-$(KernelVersion)
FileName=ShenOSKernel-$(KernelVersion).tar.gz
NestedFolderName=ShenOSKernel-$(KernelVersion)

ifeq ($(OS),Windows_NT)
	BinaryName=shen.exe
else
	BinaryName=shen
endif

RunCLisp=clisp -M ./native/clisp/shen.mem -q -m 10MB
RunCCL=./native/ccl/$(BinaryName)
RunSBCL=./native/sbcl/$(BinaryName)
BuildAll=build-clisp build-ccl build-sbcl
TestAll=test-clisp test-ccl test-sbcl

default: build-all

all: build-all test-all # TODO: add fetch here after it works on windows

fetch:
	wget $(UrlRoot)/$(ReleaseName)/$(FileName)
	tar xf $(FileName)
	rm -f $(FileName)
	rm -rf kernel
	mv $(NestedFolderName) kernel

build-all: $(BuildAll)

build-clisp:
	clisp -i install.lsp

build-ccl:
	ccl -l install.lsp

build-sbcl:
	sbcl --load install.lsp

test-all: $(TestAll)

test-clisp:
	$(RunCLisp) testsuite.shen

test-ccl:
	$(RunCCL) testsuite.shen

test-sbcl:
	$(RunSBCL) testsuite.shen

run-clisp:
	$(RunCLisp)

run-ccl:
	$(RunCCL)

run-sbcl:
	$(RunSBCL)

clisp: build-clisp test-clisp

ccl: build-ccl test-ccl

sbcl: build-sbcl test-sbcl

clean:
	rm -rf native
