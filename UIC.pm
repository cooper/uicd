# Copyright (c) 2012, Mitchell Cooper
# UIC: manages servers, users, and channels on a UIC network or server.
# performs tasks that do not fall under the subcategories of server, user, connection, or channel.
package UIC;

use warnings;
use strict;
use utf8;
use parent 'UIC::EventedObject';

use UIC::EventedObject;
use UIC::Server;
use UIC::User;
use UIC::Channel;

use Scalar::Util 'looks_like_number';

sub parse_data {
    my ($uic, $data) = @_;
    # blah blah, call handlers.
}

# register a command handler.
# $uic->register_register('someCommand', {
#     someParameter => 'number',  # an integer or decimal
#     someOther     => 'string',  # a plain old string
#     anotherParam  => 'user',    # a user ID
#     evenMoreParam => 'server',  # a server ID
#     yetAnother    => 'channel'  # a channel ID
# }, \&myHandler, 200);
# returns a handler identifier.
sub register_handler {
    my ($uic, $command, $parameters, $callback, $priority) = @_;
    $priority ||= 0;
    
    # make sure callback is CODE and parameters is HASH.
    return if !ref $callback   || ref $callback ne 'CODE';
    return if !ref $parameters || ref $parameters ne 'HASH';
    
    # make sure the types are valid.
    my @valid = qw(number string user server channel);
    foreach my $parameter (keys %$parameters) {
        return if !($parameter ~~ @valid);
    }
    
    # store the handler.
    $uic->{handlers}{$command}{$priority} ||= [];
    push @{$uic->{handlers}{$command}{$priority}}, {
        command    => $command,
        callback   => $callback,
        parameters => $parameters,
        priority   => $priority
    };
    
    return defined $uic->{handlerID} ? ++$uic->{handlerID} : $uic->{handlerID} = 0;
}

# fire a command's handlers.
# $uic->fire_handler('someCommand', {
#     someParameter => '0',
#     someOther     => 'hello!'
# });
sub fire_handler {
    my ($uic, $command, $parameters) = @_;
    
    # no handlers for this command.
    return unless $uic->{handlers}{$command};
    
    # call each handler.
    my $return = {};
    foreach my $priority (sort { $b <=> $a } keys %{$uic->{handlers}{$command}}) {
    foreach my $h (@{$obj->{events}->{$event}->{$priority}}) {
    
        # process parameter types.
        my %final_params;
        foreach my $parameter (keys %{$h->{parameters}}) {
            $final_params{$parameter} = $uic->interpret_string_as($h->{parameters}{$parameter}, $parameter);
        }
        
        # create information object.
        my %info = (
            caller   => [caller 1],
            command  => $command,
            priority => $priority
        );
        
        # call it.
        $h->{callback}(\%final_params, $return, \%info);
        
    }}
}

sub interpret_string_as {
    my ($uic, $type, $string) = @_;
    given ($type) {
        when ('string') {
            return $string.q();
        }
        when ('number') {
            if (looks_like_number($string)) {
                return $string + 0;
            }
            return 1;
        }
        when ('user') {
        }
        when ('channel') {
        }
        when ('server') {
        }
    }
    return;
}

# handler($parameters, $return, $info)

1
