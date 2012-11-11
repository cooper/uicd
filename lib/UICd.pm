# Copyright (c) 2012, Mitchell Cooper
# UICd: reprents a server instance.
# inherits from UIC, which represents a UIC object.
# (manages users, servers, channels, and more.)
package UICd;

use warnings;
use strict;
use utf8;

use UICd::Utils qw(log2 fatal gv set);

our ($VERSION, @ISA, %GV, $conf) = 1;

##############################
### CALLED BY MAIN PACKAGE ###
##############################

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
    require IO::Async::Stream;
    require IO::Socket::IP;

    # libuic and UICd.
    require UIC;
    require UICd::Configuration;
    require UICd::Connection;
    require UICd::Server;
    require UICd::User;
    require UICd::Channel;
    
    # become a child of UIC.
    unshift @ISA, 'UIC';
    
    # load the configuration.
    $conf = $GV{conf} = UICd::Configuration->new(\%main::conf, "$main::dir{etc}/uicd.conf");
    $conf->parse_config or die "Can't parse $main::dir{etc}/uicd.conf: $!\n";
    
    # create the main UICd object.
    if (!$main::UICd) {
        $main::UICd = $GV{UICd} = __PACKAGE__->new();
    }
    
    # create the IO::Async loop.
    $main::loop = IO::Async::Loop->new;
    
    # replace reloadable().
    *main::reloable = *reloadable;

    start();
    become_daemon();
}

# set up server.
sub start {

    # create the sockets and begin listening.
    create_sockets();
    
}

# create the sockets and begin listening.
sub create_sockets {
    foreach my $addr ($conf->names_of_block('listen')) {
      foreach my $port (@{$conf->get(['listen', $addr], 'port')}) {

        # create the loop listener
        my $listener = IO::Async::Listener->new(on_stream => \&handle_connect);
        $main::loop->add($listener);

        # create the socket
        my $socket = IO::Socket::IP->new(
            LocalAddr => $addr,
            LocalPort => $port,
            Listen    => 1,
            ReuseAddr => 1,
            Type      => Socket::SOCK_STREAM(),
            Proto     => 'tcp'
        ) or fatal("Couldn't listen on [$addr]:$port: $!");

        # add to looped listener
        $listener->listen(handle => $socket);

        log2("Listening on [$addr]:$port");
    } }
    return 1
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

##########################
### PACKAGE MANAGEMENT ###
##########################

sub reloadable {
}

########################
### HANDLING SIGNALS ###
########################

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

###########################
### IO::ASYNC CALLBACKS ###
###########################

# handle a new connection.
sub handle_connect {
    my ($listener, $stream) = @_;

    # if the connection limit has been reached, drop the connection.
    if ($main::UICd->number_of_connections >= $conf->get('limit', 'total_local_connections')) {
        $stream->close_now;
        return;
    }

    # if the connection IP limit has been reached, drop the connection.
    my $ip = $stream->{write_handle}->peerhost;
    if (scalar(grep { $_->{ip} eq $ip } $main::UICd->connections) >= $conf->get('limit', 'local_connections_per_ip')) {
        $stream->close_now;
        return;
    }

    # if the global IP limit has been reached, drop the connection.
    #if (scalar(grep { $_->{ip} eq $ip } values %user::user) >= conf('limit', 'global_connections_per_ip')) {
    #    $stream->close_now;
    #    return;
    #}

    # create connection object.
    my $conn = $main::UICd->new_connection($stream);

    $stream->configure(
        read_all       => 0,
        read_len       => POSIX::BUFSIZ(),
        on_read        => \&handle_data,
        on_read_eof    => sub { $main::UICd->close_connection($conn, 'Connection closed'); $stream->close_now   },
        on_write_eof   => sub { $main::UICd->close_connection($conn, 'Connection closed'); $stream->close_now   },
        on_read_error  => sub { $main::UICd->close_connection($conn, 'Read error: ' .$_[1]); $stream->close_now },
        on_write_error => sub { $main::UICd->close_connection($conn, 'Write error: '.$_[1]); $stream->close_now }
    );

    $main::loop->add($stream);
}

# handle incoming data.
sub handle_data {
    my ($stream, $buffer) = @_;
    my $connection = $main::UICd->lookup_connection_by_stream($stream);
    while ($$buffer =~ s/^(.*?)\n//) {
        $connection->handle($1);
    }
}

############################
### MANAGING CONNECTIONS ###
############################

# create a connection and associate it with this UICd object.
sub new_connection {
    my ($uicd, $stream) = @_;
    my $connection = UICd::Connection->new($stream);
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

# dispose of a connection.
sub remove_connection {
    my ($uicd, $connection) = @_;
    delete $uicd->{connections}{$connection->{stream}};
    log2("scalar \%connections: ".scalar(keys %{$uicd->{connections}}));
}

# number of current connections.
sub number_of_connections {
    my $uicd = shift;
    return scalar keys %{$uicd->{connections}};
}

# returns a list of active connections.
sub connections {
    my $uicd = shift;
    return values %{$uicd->{connections}};
}

# find a connection by its stream.
sub lookup_connection_by_stream {
    my ($uicd, $stream) = @_;
    return $uicd->{connections}{$stream};
}

# end and delete a connection.
sub close_connection {
    my ($uicd, $connection, $reason, $silent) = @_;
    log2("Closing connection from $$connection{ip}: $reason");
    $connection->done($reason, $silent);
    $uicd->remove_connection($connection);
}

#####################
### UIC OVERRIDES ###
#####################

# parse a line of data.
# this overrides UIC::parse_data().
sub parse_data {
    my ($uic, $data) = @_;
    log2("parsing data: $data");
}


1
