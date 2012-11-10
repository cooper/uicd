# Copyright (c) 2012, Mitchell Cooper
# UICd: reprents a server instance.
# inherits from UIC, which represents a UIC object.
# (manages users, servers, channels, and more.)
package UICd;

use warnings;
use strict;
use utf8;

our ($VERSION, @ISA, %GV, $conf) = 1;

# BEGIN block.
sub begin {
    %GV = (
    
        # software-related variables.
        NAME    => 'uicd',
        VERSION => $VERSION,
        PROTO   => 1,
        START   => time,
        NOFORK  => 'NOFORK' ~~ @ARGV,
        
        # variables that need to be set to a zero value.
        connection_count      => 0,
        max_connection_count  => 0,
        max_global_user_count => 0,
        max_local_user_count  => 0
        
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
    $conf = UICd::Configuration->new(\%main::conf, "$main::dir{etc}/uicd.conf");
    $conf->parse_config or die "Can't parse $main::dir{etc}/uicd.conf: $!\n";
    
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
        open my $pidfh, '>', "$main::dir{run}/$GV{NAME}.pid" or die;
        $GV{PID} = fork;
        say $pidfh $GV{PID} if $GV{PID};
        close $pidfh;
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

############################
### MANAGING CONNECTIONS ###
############################

# create a connection and associate it with this UICd object.
sub new_connection {
    my ($uicd, $stream) = @_;
    my $connection = connection->new($stream);
    $uicd->set_connection_for_stream($stream, $connection);
    
    # update total connection count
    my $count = gv('connection_count');
    set('connection_count', $count + 1);

    # update maximum connection count
    if ($uicd->number_of_connections + 1 > gv('max_connection_count')) {
        set('max_connection_count', $uicd->number_of_connections + 1);
    }

    return $connection;
}

# associate a connection with a stream.
sub set_connection_for_stream {
    my ($uicd, $stream, $connection) = @_;
    $uicd->{connections}{$stream} = $connection;
    return $connection;
}

# number of current connections.
sub number_of_connections {
    my $uicd = shift;
    return scalar keys %{$uicd->{connections}};
}

1
