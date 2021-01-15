#! /bin/bash
/opt/gyre/bin/mu-exec                              \
    -l /opt/gyre/src/core/mu.l                     \
    -l /opt/gyre/src/core/core.l                   \
    -q '(:defsym lib-base "/opt/gyre")'            \
    -q '(require gyre/canon "/src/gyre/lib.l")'    \
    -q '(in-ns (ns "user" (find-ns "gyre")))'      \
    "$@"                                           \
    -e '(repl)'
