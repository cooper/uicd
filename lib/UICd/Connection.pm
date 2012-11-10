# Copyright (c) 2012, Mitchell Cooper
# UICd::Connection: represents a connection to a UIC server.
# Connections may be associated with a specific user, but by no means do they have to be.
package UICd::Connection;

use warnings;
use strict;
use utf8;
use parent 'UIC::EventedObject';

use UICd::Utils qw(gv set);

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

1
