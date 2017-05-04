KernelVersion=20.0

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
ReleaseName=shen-$(KernelVersion)
FileName=ShenOSKernel-$(KernelVersion).tar.gz
NestedFolderName=ShenOSKernel-$(KernelVersion)

RunCLisp=clisp -M ./native/clisp/shen.mem -q -m 10MB
BuildAll=build-clisp build-ccl build-sbcl
TestAll=test-clisp test-sbcl
# TODO: TestAll=test-clisp test-ccl test-sbcl

ifeq ($(OS),Windows_NT)
	RunCCL=./native/ccl/shen.exe
	RunSBCL=./native/sbcl/shen.exe
else
	RunCCL=./native/ccl/shen
	RunSBCL=./native/sbcl/shen
endif

build-all: $(BuildAll)

test-all: $(TestAll)

build-clisp:
	clisp -i install.lsp

build-ccl:
	ccl -l install.lsp

build-sbcl:
	sbcl --load install.lsp

run-clisp:
	$(RunCLisp)

run-ccl:
	$(RunCCL)

run-sbcl:
	$(RunSBCL)

test-clisp:
	$(RunCLisp) testsuite.shen

test-ccl:
	$(RunCCL) testsuite.shen

test-sbcl:
	$(RunSBCL) testsuite.shen

fetch:
	wget $(UrlRoot)/$(ReleaseName)/$(FileName)
	tar xf $(FileName)
	rm -f $(FileName)
	rm -rf kernel
	mv $(NestedFolderName) kernel

clean:
	rm -rf native
