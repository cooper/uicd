# Copyright (c) 2012, Mitchell Cooper
# UICd: reprents a server instance.
# inherits from UIC, which represents a UIC object
# (manages users, servers, channels, and more.)
package UICd;

use warnings;
use strict;
use utf8;
use feature qw(switch say);

our ($VERSION, @ISA, %GV) = 1;

# BEGIN block.
sub begin {
    %GV = (
        NAME    => 'uicd',
        VERSION => $VERSION,
        PROTO   => 1,
        START   => time,
        NOFORK  => 'NOFORK' ~~ @ARGV,
    );
}

# load requirements and set up the loop.
sub boot {
    require POSIX;
    require IO::Async::Loop;
    require IO::Async::Listener;
    require IO::Async::Timer::Periodic;
    require IO::Socket::IP;
    require UIC;
    
    unshift @ISA, 'UIC';

    $main::loop = IO::Async::Loop->new;
    
    *main::reloable = *reloadable;

    start();
    become_daemon();
}

# set up server.
sub start {
}

# become a daemon.
sub become_daemon {

    # unless NOFORK enabled, fork.
    if (!$GV{NOFORK}) {

        # since there will be no input or output from here on,
        # open the filehandles to /dev/null
        open STDIN,  '<', '/dev/null' or die;
        open STDOUT, '>', '/dev/null' or die;
        open STDERR, '>', '/dev/null' or die;

        # write the PID file that is used by the start/stop/rehash script.
        open my $pidfh, '>', "$main::run_dir/etc/$GV{NAME}.pid" or die;
        $GV{PID} = fork;
        say $pidfh $GV{PID} if $GV{PID};
        close $pidfh
    }

    exit if $GV{PID};
    POSIX::setsid();
}

# begin the running loop.
sub loop {
    $main::loop->loop_forever;
}

# stop the uicd.
sub terminate {

}

# handle a HUP.
sub signalhup {
}

# handle a PIPE.
sub signalpipe {
}

# handle a warning.
sub WARNING {
}

sub reloadable {
}

1
