# Copyright (c) 2012, Mitchell Cooper
# UICd: reprents a server instance.
# inherits from UIC, which represents a UIC object.
# (manages users, servers, channels, and more.)
package UICd;

use warnings;
use strict;
use utf8;
use feature qw(switch say);

our ($VERSION, @ISA, %GV, $conf) = 1;

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

    # base requirements.
    require POSIX;
    
    # IO::Async and friends.
    require IO::Async::Loop;
    require IO::Async::Listener;
    require IO::Async::Timer::Periodic;
    require IO::Socket::IP;

    # libuic and UICd.
    require UIC;
    require UICd::Configuration;
    require UICd::Connection;
    require UICd::Server;
    require UICd::User;
    require UICd::Channel;
    
    # load the configuration.
    $conf = UICd::Configuration->new(\%main::conf, "$main::run_dir/etc/uicd.conf");
    $conf->parse_config or die "Can't parse uicd.conf: $!\n";
    
    # become a child of UIC.
    unshift @ISA, 'UIC';

    # create the IO::Async loop.
    $main::loop = IO::Async::Loop->new;
    
    # replace reloadable().
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
