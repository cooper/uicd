# Copyright (c) 2012, Mitchell Cooper
# UICd::Connection: represents a connection to a UIC server.
# Connections may be associated with a specific user or server, but by no means do they have to be.
package UICd::Connection;
# XXX CONNECTION OBJECTS ARE MEMORY LEAK!!! XXX
use warnings;
use strict;
use utf8;
use parent 'UIC::EventedObject';

use UICd::Utils qw(gv set log2 fatal);

# create a new connection.
sub new {
    my ($class, $stream) = @_;
    return unless defined $stream;

    bless my $connection = {
        stream        => $stream,
        ip            => $stream->{write_handle}->peerhost,
        source        => gv('SERVER', 'sid'),
        connect_time  => time,
        #last_ping     => time,
        #last_response => time
    }, $class;

    # eventually hostnames will be resolved here.
    $connection->{host} = $connection->{ip};

    return $connection;
}

# end the connection.
sub done {

    my ($connection, $reason, $silent) = @_;

#    if ($connection->{type}) {
#        # share this quit with the children
#        server::mine::fire_command_all(quit => $connection, $reason) unless $connection->{type}->isa('server');
#
#        # tell user.pm or server.pm that the connection is closed
#        $connection->{type}->quit($reason)
#    }
#    $connection->send("ERROR :Closing Link: $$connection{host} ($reason)") unless $silent;

    $connection->{stream}->close_when_empty;


    #delete $connection->{type}->{conn};
    #delete $connection->{type};

    return 1

}

sub DESTROY {
    my $conn = shift;
    log2("disposing of connection to $$conn{ip}");
    exit;
}

1
