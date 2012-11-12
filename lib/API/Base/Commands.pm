# Copyright (c) 2012, Mitchell Cooper
package API::Base::Commands;

use warnings;
use strict;

use UICd::Utils 'log2';

# registers a connection command handler.
sub register_connection_command_handler {
    my ($mod, %opts) = @_;

    # make sure all required options are present.
    foreach my $what (qw|command description callback|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        log2("command '$opts{command}' does not have '$what' option.");
        return
    }

    # register the handler to UICd.
    # unlike in juno-ircd, the low-level API checks for validity of types.
    my $handlerID = $main::UICd->register_handler(
        "connection.$opts{command}",
        $opts{parameters},
        $opts{callback},
        $opts{priority} || 0,
        (caller)[0]
    );
    
    # the UICd refused to accept this handler configuration.
    if (!defined $handlerID) {
        log2("uicd refused to register handler for command '$opts{command}'");
        return;
    }

    # store the handler ID for later.    
    $mod->{connection_command_handlers} ||= [];
    push @{$mod->{connection_command_handlers}}, $handlerID;
    return 1;
}

# unload command handlers.
sub unload {
    my ($class, $mod) = @_;
    log2("disposing of commands registered by uicd module '$$mod{name}'");
    # delete_handler...
    log2("done unloading commands");
    return 1
}

1
