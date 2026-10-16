# SHA-256 host extension

This optional extension provides `shen.x.sha256-octets-host`, a Common Lisp
backend for the portable Shen extension API. Its code and registration are
contained in this directory. It is loaded explicitly into a running Shen CL
process and has no external Lisp library dependencies.

From the checkout or extracted release directory, enable it with:

```shen
(shen-cl.load-lisp "extensions/sha256/sha256.lsp")
```

The path is relative to the process's working directory; an absolute path also
works. The function accepts a proper list of integer octets from 0 through 255
and returns a list of the 32 digest octets:

```shen
(shen.x.sha256-octets-host [97 98 99])
((fn shen.x.sha256-octets-host) [97 98 99])
```

Loading registers its callable metadata, advertises `shen.x/sha256-host` through
`shen.x.features.current`, and sets `shen.x.*sha256-backend*` to `host`.
Portable libraries can use this backend through their existing extension API.
`SHEN_X_SHA256=pure` retains the portable-backend override: it suppresses host
registration when loading the file and sets the backend marker to `pure`.
The digest implementation itself remains callable from Lisp.

The normal executable starts without this extension. Kernel archive verification
continues to use the system checksum utility.

Run the extension's known digest vectors, padding boundaries, callable metadata,
and input validation checks on the SBCL build with:

```sh
make test-sha256
```
