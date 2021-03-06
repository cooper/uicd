# Copyright (c) 2012, Mitchell Cooper
# UICd::Connection: represents a connection to a UIC server.
# Connections may be associated with a specific user or server, but by no means do they have to be.
package UICd::Connection;
# XXX CONNECTION OBJECTS ARE MEMORY LEAK!!! XXX
use warnings;
use strict;
use utf8;
use feature 'switch';
use parent 'EventedObject';

use UICd::Utils qw(gv set log2 fatal conf);

# create a new connection.
sub new {
    my ($class, $stream) = @_;
    return unless defined $stream;

    bless my $connection = {
        stream        => $stream,
        ip            => $stream->{write_handle}->peerhost,
        connect_time  => time,
        last_ping     => time,
        last_response => time
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

    $connection->{goodbye} = 1;
    #delete $connection->{type}->{conn};
    #delete $connection->{type};

    return 1

}

sub handle {
    my ($connection, $data) = @_;

    $connection->{ping_in_air}   = 0;
    $connection->{last_response} = time;

    # strip unwanted characters.
    $data =~ s/(\n|\r|\0)//g;

    # connection is being closed
    return if $connection->{goodbye};

    # parse the line.
    if (my $errors = $main::UICd->parse_data($data, $connection)) {
    
        # forcibly send an error immediately.
        $connection->send('syntaxError', $errors);
        
        # close the connection.
        $main::UICd->close_connection($connection, 'Syntax error');
        
    }

}

# send initial messages.
sub welcome {
    my $connection = shift;
    $connection->send('hello', {
        network     => conf('server', 'network_name'),
        id          => \conf('server', 'id'),
        name        => conf('server', 'name'),
        description => conf('server', 'description'),
        software    => gv('NAME'),
        version     => gv('VERSION'),
        server      => UIC::TRUE
    });
}

# send a message.
sub send {
    my ($connection, $command, $parameters, $callback, $callback_params) = @_;
    
    # if a return callback was supplied, generate a message identifier.
    my $id = defined $connection->{messageID} ? ++$connection->{messageID} : ($connection->{messageID} = 0) if $callback;

    # encode the message.
    my $message = UIC::Parser::encode(
        command_name => $command,
        parameters   => $main::UICd->prepare_parameters_for_sending($parameters),
        message_id   => $id
    ) or return;
    
    # register the return handler if there is one.
    $main::UICd->register_return_handler($id, $callback, $callback_params) if $callback;
    
    # write the message.
    $connection->{stream}->write("$message\n");
    
}

sub DESTROY {
    my $connection = shift;
    log2("disposing of connection to $$connection{ip}");
    exit;
}

1
