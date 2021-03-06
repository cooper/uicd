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
        when (1) { return $main::GV{+shift}                 }
        when (2) { return $main::GV{+shift}{+shift}         }
        when (3) { return $main::GV{+shift}{+shift}{+shift} }
    }
    return;
}

# GV set
sub set ($$) {
    $main::GV{+shift} = shift;
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
    my $level = '    ' x $main::GV{log_level} if $Utils::GV{indenting_logs};
    $level ||= ' ';
    say(time().$level.($sub && $sub ne '(eval)' ? "$sub():" : q([).(caller)[0].q(])).q( ).$line);
}

# increase/decrease logging level.
sub increase_level { return unless $Utils::GV{indenting_logs}; $main::GV{log_level}++; say '' }
sub decrease_level { return unless $Utils::GV{indenting_logs}; $main::GV{log_level}--; say '' }

# log and exit. a third argument exits with no error.
sub fatal {
    my $line = shift;
    my $sub = (caller 1)[3];
    log2(($sub ? "$sub(): " : q..).$line);
    exit(shift() ? 0 : 1);
}

# alias to $conf->get
sub conf {
    return $main::conf->get(@_);
}

1
