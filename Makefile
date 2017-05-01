KernelVersion=20.0

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
ReleaseName=shen-$(KernelVersion)
FileName=ShenOSKernel-$(KernelVersion).tar.gz
NestedFolderName=ShenOSKernel-$(KernelVersion)

RunCLisp=clisp -M ./native/clisp/shen.mem -q -m 10MB

ifeq ($(OS),Windows_NT)
	RunSBCL=./native/sbcl/shen.exe
else
	RunSBCL=./native/sbcl/shen
endif

build-all: build-clisp build-sbcl

build-clisp:
	clisp -i install.lsp

build-sbcl:
	sbcl --load install.lsp

run-clisp:
	$(RunCLisp)

run-sbcl:
	$(RunSBCL)

test-all: test-clisp test-sbcl

test-clisp:
	$(RunCLisp) testsuite.shen

test-sbcl:
	$(RunSBCL) testsuite.shen

fetch:
	wget $(UrlRoot)/$(ReleaseName)/$(FileName)
	tar xf $(FileName)
	rm -f $(FileName)
	rm -rf kernel
	mv $(NestedFolderName) kernel
