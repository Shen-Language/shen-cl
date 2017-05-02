KernelVersion=20.0

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
ReleaseName=shen-$(KernelVersion)
FileName=ShenOSKernel-$(KernelVersion).tar.gz
NestedFolderName=ShenOSKernel-$(KernelVersion)

ifeq ($(OS),Windows_NT)
	RunSBCL=./native/sbcl/shen.exe
	CCL=wx86cl64
else
	RunSBCL=./native/sbcl/shen
	CCL=ccl64
endif

RunCLisp=clisp -M ./native/clisp/shen.mem -q -m 10MB
RunCCL=$(CCL) -I ./native/ccl/shen.mem

build-all: build-clisp build-sbcl
# build-all: build-clisp build-ccl build-sbcl

build-clisp:
	clisp -i install.lsp

build-ccl:
	$(CCL) -l install.lsp

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
