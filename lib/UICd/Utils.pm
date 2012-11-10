# Copyright (c) 2012, Mitchell Cooper
# utils: commonly used utilities and conveniences.
package UICd::Utils;

use warnings;
use strict;
use utf8;
use feature qw(switch say);

# import/export.
sub import {
    my $package = caller;
    no strict 'refs';
    *{$package.'::'.$_} = *{__PACKAGE__.'::'.$_} foreach @_[1..$#_];
}

# GV
sub gv {
    # can't use do{given{ ... }}
    # compatibility with 5.12 XXX
    given (scalar @_) {
        when (1) { return $UICd::GV{+shift}                 }
        when (2) { return $UICd::GV{+shift}{+shift}         }
        when (3) { return $UICd::GV{+shift}{+shift}{+shift} }
    }
    return;
}

# remove leading and trailing whitespace.
sub trim {
    my $string = shift;
    $string =~ s/\s+$//;
    $string =~ s/^\s+//;
    return $string;
}

# log errors/warnings.
sub log2 {
    return if !$main::NOFORK  && defined $main::PID;
    my $line = shift;
    my $sub = (caller 1)[3];
    say(time.q( ).($sub && $sub ne '(eval)' ? "$sub():" : q([).(caller)[0].q(])).q( ).$line)
}

# log and exit. a third argument exits with no error.
sub fatal {
    my $line = shift;
    my $sub = (caller 1)[3];
    log2(($sub ? "$sub(): " : q..).$line);
    exit(shift() ? 0 : 1)
}

1
