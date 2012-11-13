# Copyright (c) 2012, Mitchell Cooper
package API::Base::Commands;

use warnings;
use strict;

use UICd::Utils 'log2';

# registers a global command handler.
sub register_global_command_handler {
    return _register_handler('', shift, (caller)[0], @_);
}

# registers a connection command handler.
sub register_connection_command_handler {
    return _register_handler('connection.', shift, (caller)[0], @_);
}

# registers a handler of $type to $mod with %opts options.
# not intended to be used directly - use one of the above methods instead.
sub _register_handler {
    my ($type, $mod, $caller, %opts) = @_;

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
        "$type$opts{command}",
        $opts{parameters},
        $opts{callback},
        $opts{priority} || 0,
        $caller
    );
    
    # the UICd refused to accept this handler configuration.
    if (!defined $handlerID) {
        log2("libuic refused to register handler for '$opts{command}' command");
        return;
    }

    # store the handler ID for later.    
    $mod->{connection_command_handlers} ||= [];
    push @{$mod->{connection_command_handlers}}, $handlerID;
    
    log2("module '$$mod{name}' registered handler for '$opts{command}' successfully");
    return 1;
}

# unload command handlers.
sub _unload {
    my ($class, $mod) = @_;
    log2("disposing of commands registered by uicd module '$$mod{name}'");
    # delete_handler...
    log2("done unloading commands");
    return 1
}

1
