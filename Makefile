KernelVersion=20.0

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
ReleaseName=shen-$(KernelVersion)
FileName=ShenOSKernel-$(KernelVersion).tar.gz
NestedFolderName=ShenOSKernel-$(KernelVersion)

ifeq ($(OS),Windows_NT)
	RunCCL=./native/ccl/shen.exe
	RunSBCL=./native/sbcl/shen.exe
else
	RunCCL=./native/ccl/shen
	RunSBCL=./native/sbcl/shen
endif

RunCLisp=clisp -M ./native/clisp/shen.mem -q -m 10MB

build-all: build-clisp build-sbcl
# build-all: build-clisp build-ccl build-sbcl

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

test-all: test-clisp test-sbcl
# test-all: test-clisp test-ccl test-sbcl

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
