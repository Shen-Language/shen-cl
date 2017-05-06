KernelVersion=20.1

UrlRoot=https://github.com/Shen-Language/shen-sources/releases/download
ReleaseName=shen-$(KernelVersion)
NestedFolderName=ShenOSKernel-$(KernelVersion)

ifeq ($(OS),Windows_NT)
	FileName=ShenOSKernel-$(KernelVersion).zip
	BinaryName=shen.exe
else
	FileName=ShenOSKernel-$(KernelVersion).tar.gz
	BinaryName=shen
endif

RunCLisp=clisp -M ./native/clisp/shen.mem -q -m 10MB
RunCCL=./native/ccl/$(BinaryName)
RunSBCL=./native/sbcl/$(BinaryName)
BuildAll=build-clisp build-ccl build-sbcl
TestAll=test-clisp test-ccl test-sbcl

default: build-all

all: fetch build-all test-all

fetch:
ifeq ($(OS),Windows_NT)
	powershell.exe -Command "Invoke-WebRequest -Uri $(UrlRoot)/$(ReleaseName)/$(FileName) -OutFile $(FileName)"
	powershell.exe -Command "Expand-Archive $(FileName) -DestinationPath ."
	rm -f $(FileName)
	rm -rf kernel
	mv $(NestedFolderName) kernel
else
	wget $(UrlRoot)/$(ReleaseName)/$(FileName)
	tar xf $(FileName)
	rm -f $(FileName)
	rm -rf kernel
	mv $(NestedFolderName) kernel
endif

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
	rm -rf kernel native
