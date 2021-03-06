# Copyright (c) 2012, Mitchell Cooper
# Core::ConnectionCommands: register connection commands, global commands, etc.
package API::Module::Core::ConnectionCommands;

use warnings;
use strict;
use utf8;
use API::Module;

use UICd::Utils 'log2';

our $mod = API::Module->new(
    name        => 'Core::ConnectionCommands',
    version     => '0.7',
    description => 'the core set of pre-registration and global commands',
    requires    => ['Commands'],
    initialize  => \&init
);

sub init {

    $mod->register_global_command_handler(
        command     => 'return',
        description => 'handle message return values',
        callback    => \&handle_return,
        parameters  => {},
        priority    => 0
    ) or return;

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
        },
        priority => 0
    ) or return;

    return 1;   
}

#######################
### GLOBAL COMMANDS ###
#######################

# return command.
sub handle_return {
    my ($param, $return, $info) = @_;

    # useless if we don't have a message ID.
    return unless defined $param->{messageID};
    
    # fire the return handlers.
    $main::UICd->fire_return($param->{messageID}, $param, $info);

}

###########################
### CONNECTION COMMANDS ###
###########################

# hello command.
# registers and authenticates a connection.
sub handle_hello {
    my ($param, $return, $info) = @_;
    
    # TODO: make sure not already registered. (connection command would not fire if so).
    # PS: don't force exit.

    # user registration.
    if ($param->{user}) {
    
        # make sure all require parameters are present.
        if (!$param->has(qw|name software version nickname|)) {
            # PARAMETER ERROR.
            return;
        }
        
        $info->{new_user} = $main::UICd->new_user(
            id       => $info->{server}->next_user_id,
            name     => $param->{name},
            software => $param->{software},
            version  => $param->{version},
            nickname => $param->{nickname}
        );
    }
    
    # server registration.
    elsif ($param->{server}) {

    }
    
    # neither a server not a user. illegal alien.
    else {
        $info->{connection}->send('registrationError', {
            message => 'attempted to register as neither a server not a user'
        });
                
        # TODO: discard the connection.
        return;
    }
    
    # do other stuff after registering.
    return 1;
    
}

$mod
