KernelVersion=20.0

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
ReleaseName=shen-$(KernelVersion)
FileName=ShenOSKernel-$(KernelVersion).tar.gz
NestedFolderName=ShenOSKernel-$(KernelVersion)

RunCLisp=clisp -M ./native/clisp/shen.mem -q -m 10MB

build-all: build-clisp build-sbcl

build-clisp:
	clisp -i install.lsp

build-sbcl:
	sbcl --load install.lsp

run-clisp:
	$(RunCLisp)

run-sbcl:
ifeq ($(OS),Windows_NT)
	./native/sbcl/shen.exe
else
	./native/sbcl/shen
endif

test-all: test-clisp test-sbcl

test-clisp:
	$(RunCLisp) testsuite.shen

test-sbcl:
ifeq ($(OS),Windows_NT)
	./native/sbcl/shen.exe testsuite.shen
else
	./native/sbcl/shen testsuite.shen
endif

fetch:
	wget $(UrlRoot)/$(ReleaseName)/$(FileName)
	tar xf $(FileName)
	rm -f $(FileName)
	rm -rf kernel
	mv $(NestedFolderName) kernel

