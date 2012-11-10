# Copyright (c) 2012, Mitchell Cooper
# utils: commonly used utilities and conveniences.
package UICd:Utils;

# GV
sub gv {
    # can't use do{given{ ... }}
    # compatibility with 5.12 XXX
    given (scalar @_) {
        when (1) { return $UICd::GV{+shift}                 }
        when (2) { return $UICd::GV{+shift}{+shift}         }
        when (3) { return $UICd::GV{+shift}{+shift}{+shift} }
    }
    return
}

1
