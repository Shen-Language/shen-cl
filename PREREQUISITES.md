# TODO: cover ABCL in this doc

# Prerequisites

  * For [BSD](#bsd)
  * For [Linux](#linux)
  * For [macOS](#macos)
  * For [Windows](#windows)

You will need to have recent versions of the Common Lisp implementations you want to work with installed and available as the `Makefile` requires. Installation is different depending on operating system.

Support for Common Lisp implementations varies over different operating systems. By default, only implementations available in binary form are built with the `make all` command. Check the value of the `All` variable in the `Makefile` to see which are supported for your OS and architecture.

Check the project page for any CL implementation to build from source if necessary.

## BSD

Below is a summary of currently supported implementations per BSD variant. As always, you should check for yourself the availability of these CLs with the package manager of the particular BSD you are running, e.g., `pkg search sbcl` or `pkg_info -Q sbcl`.

|       | FreeBSD            | OpenBSD         | NetBSD                     |
|:------|:-------------------|:----------------|:---------------------------|
| CLisp | N/A                | `pkg_add clisp` | `pkg_add clisp`            |
| CCL   | `pkg install ccl`  | N/A             | N/A                        |
| ECL   | `pkg install ecl`  | `pkg_add ecl`   | `pkg_add ecl`              |
| SBCL  | `pkg install sbcl` | `pkg_add sbcl`  | `pkg_add sbcl` (i386 Only) |

Also, you will need to install GNU make. This repo's `Makefile` is a GNU make makefile and typing `make ...` is likely to invoke the system make (BSD make) and quit on you harshly, complaining about parsing errors. Hence, it is necessary to ensure that the `gmake` package/port is installed, and replace `make ...` in the instructions below with `gmake ...`.

## Linux

CLisp, ECL and SBCL are available through `apt`. Just run `sudo apt install clisp ecl sbcl`.

ECL requires `libffi-dev` to build, which can also be retrieved through `apt`.

There is a [separately available debian package](http://mr.gy/blog/clozure-cl-deb.html) for Clozure. Download and install with `dpkg -i`.

If the version of SBCL available throught `apt` is too old, a sufficiently new version is [available from debian](http://http.us.debian.org/debian/pool/main/s/sbcl/sbcl_1.4.2-1_arm64.deb).

## macOS

ABCL, CLisp, Clozure, ECL and SBCL can be acquired through Homebrew with `brew install abcl clisp clozure-cl ecl sbcl`.

## Windows

CLisp has an installer and a zip package on [SoureForge](https://sourceforge.net/projects/clisp/files/clisp/2.49/). You'll have to include `clisp.exe` as well as `libintl-8.dll` and `libreadline6.dll` in on your PATH to ensure the clisp build of shen-cl will run.

Clozure will need to be installed manually:
  * Download the zip from [here](https://ccl.clozure.com/download.html) and extract it under `Program Files`.
  * Add the Clozure directory to your `PATH` or add a script named `ccl.cmd` to somewhere in your `PATH` containing something like:

```batch
@echo off
"C:\Program Files\ccl\wx86cl64.exe" %*
```

ECL needs to be [built from source](https://common-lisp.net/project/ecl/static/files/release/). Refer to the [appveyor.yml](https://gitlab.com/embeddable-common-lisp/ecl/blob/develop/appveyor.yml) config for build procedure. Requires [Visual Studio 2015+](https://www.visualstudio.com/downloads/) tools. ECL support is spotty on Windows and is not included in `make all` when on Windows.

SBCL has an msi package on its [download page](http://www.sbcl.org/platform-table.html).

The `Makefile` is not very Windows-friendly, so a toolset like [GOW](https://github.com/bmatzelle/gow) can fill the gap, or use [MGWIN](http://www.mingw.org/) or [Cygwin](https://www.cygwin.com/).

The `Makefile` also requires [Powershell at version 4 or higher](https://www.microsoft.com/en-us/download/confirmation.aspx?id=54616)).
