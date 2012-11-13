# Copyright (c) 2012, Mitchell Cooper
package API::Module::Core::ConnectionCommands;

use warnings;
use strict;
use utf8;
use API::Module;

use UICd::Utils 'log2';

our $mod = API::Module->new(
    name        => 'Core::ConnectionCommands',
    version     => '0.7',
    description => 'the core set of pre-registration commands',
    requires    => 'Commands',
    initialize  => \&init
);

sub init {

    $mod->register_connection_command_handler(
        command     => 'hello',
        description => 'register and authenticate a connection',
        callback    => \&handle_hello,
        parameters  => {
            name       => t_string,
            nickname   => t_string,
            software   => t_string,
            version    => t_string,
            uicVersion => t_number,
            user       => t_boolean,
            server     => t_boolean
        }
    );

}

# hello command.
# registers and authenticates a connection.
sub handle_hello {
    my ($param, $return, $info) = @_;
    
    # user registration.
    if ($param->{user}) {
        return 1;
    }
    
    # server registration.
    elsif ($param->{server}) {
        return 1;
    }
    
    # neither a server nor a user. illegal alien.
    $info->{connection}->send('registrationError', {
        message => 'attempted to register as neither a server not a user'
    });

    return;
}

$mod
