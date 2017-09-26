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

build-test-all: build-all test-all

build-all: build-clisp build-ccl build-ecl build-sbcl

build-clisp:
	clisp -i install.lsp

build-ccl:
	ccl -l install.lsp

build-ecl:
	ecl -norc -load install.lsp

build-sbcl:
	sbcl --load install.lsp

test-all: test-clisp test-ccl test-ecl test-sbcl

test-clisp:
	$(RunCLisp) -l testsuite.shen

test-ccl:
	$(RunCCL) -l testsuite.shen

test-ecl:
	$(RunECL) -l testsuite.shen

test-sbcl:
	$(RunSBCL) -l testsuite.shen

run-clisp:
	$(RunCLisp) $(Args)

run-ccl:
	$(RunCCL) $(Args)

run-ecl:
	$(RunECL) $(Args)

run-sbcl:
	$(RunSBCL) $(Args)

clisp: build-clisp test-clisp

ccl: build-ccl test-ccl

ecl: build-ecl test-ecl

sbcl: build-sbcl test-sbcl

clean:
	rm -rf native
