# Copyright (c) 2012, Mitchell Cooper
package API::Module::Core::ConnectionCommands;

use warnings;
use strict;
use utf8;
use API::Module;

our $mod = API::Module->new(
    name        => 'Core::ConnectionCommands',
    version     => '0.7',
    description => 'the core set of pre-registration commands',
    requires    => 'Commands',
    initialize  => \&init
);

sub init {

    $mod->register_connection_command_handler(
        command    => 'hello',
        parameters => {
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

$mod
