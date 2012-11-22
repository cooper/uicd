# Copyright (c) 2012, Mitchell Cooper
# API: loads, unloads, and manages UICd modules.
package API;

use warnings;
use strict;
use utf8;
use feature 'switch';

use UICd::Utils qw(conf log2 gv set increase_level decrease_level);

use Scalar::Util 'blessed';

# load modules in the configuration.
sub load_config {
    log2('Loading configuration modules');
    increase_level();
    
    foreach my $module ($UICd::conf->keys_of_block('modules')) {
        load_module($module);
    }
    
    decrease_level();
    log2('Done loading modules');
}

# load a module.
sub load_module {
    my $name = shift;

    # if we haven't already, load API::Module.
    if (!$INC{'API/Module.pm'}) {
        require API::Module;
    }

    # make sure it hasn't been loaded previously.
    foreach my $mod (@main::loaded_modules) {
        next unless $mod->{name} eq $name;
        log2("module '$name' appears to be loaded already.");
        return;
    }

    # load the module.
    log2("loading module '$name'");
    my $loc    = $name; $loc =~ s/::/\//g;
    my $file   = $main::dir{mod}.q(/).$loc.q(.pm);
    my $module = do $file;
    
    # error in do().
    if (!$module) {
        log2("couldn't load $file: ".($! ? $! : $@));
        class_unload("API::Module::${name}");
        return;
    }

    # make sure it returned an API::Module.
    if (!blessed($module) || !$module->isa('API::Module')) {
        log2("module '$name' did not return an API::Module object.");
        class_unload("API::Module::${name}");
        return;
    }

    # second check that the module doesn't exist already.
    # we really should check this earlier as well, seeing as subroutines and other symbols
    # could have been changed beforehand. this is just a double check.
    foreach my $mod (@main::loaded_modules) {
        next unless $mod->{package} eq $module->{package};
        log2("module '$$module{name}' appears to be loaded already.");
        class_unload("API::Module::${name}");
        return;
    }

    # load the requirements if they are not already
    load_requirements($module) or log2("$name: could not satisfy dependencies") and
                                  class_unload("API::Module::${name}")          and
                                  return;

    # initialize
    log2("$name: initializing module");
    eval { $module->{initialize}->() } or
    log2($@ ? "module '$name' failed with error: $@" : "module '$name' refused to load") and
    class_unload("API::Module::${name}") and
    return;

    log2("uicd module '$name' loaded successfully");
    push @main::loaded_modules, $module;
    return 1
}

# unload a module.
sub unload_module {
    my ($name, $file) = @_;

    # find it..
    my $mod;
    foreach my $module (@main::loaded_modules) {
        next unless $module->{name} eq $name;
        $mod = $module;
        last;
    }

    if (!$mod) {
        log2("cannot unload module '$name' because it does not exist.");
        return
    }

    # unload all of its commands, loops, modes, etc.
    # then, unload the package.
    call_unloads($mod);
    class_unload($mod->{package});

    # remove from @loaded_modules
    @main::loaded_modules = grep { $_ != $mod } @main::loaded_modules;

    # call void if exists.
    if ($mod->{void}) {
        $mod->{void}->()
        or log2("module '$$mod{name}' refused to unload")
        and return;
    }

    return 1
}

# load all of the API::Base requirements for a module.
sub load_requirements {
    my $mod = shift;
    return unless $mod->{requires};
    return if ref $mod->{requires} ne 'ARRAY';

    load_base($_) or return foreach @{$mod->{requires}};

    return 1
}

# attempt to load an API::Base.
sub load_base {
    my $base = ucfirst shift;
    return 1 if $INC{"API/Base/$base.pm"}; # already loaded
    log2("loading base '$base'");
    do "$main::dir{lib}/API/Base/$base.pm" or log2("Could not load base '$base'") and return;
    unshift @API::Module::ISA, "API::Base::$base";
    return 1;
}

# call ->_unload for each API::Base.
sub call_unloads {
    my $module = shift;
    $_->_unload($module) foreach @API::Module::ISA;
}

# unload a class and its symbols.
# from Class::Unload on CPAN.
# copyright (c) 2011 by Dagfinn Ilmari MannsÃ¥ker.
sub class_unload {
    my $class = shift;
    no strict 'refs';

    # Flush inheritance caches
    @{$class . '::ISA'} = ();

    my $symtab = $class.'::';
    # Delete all symbols except other namespaces
    for my $symbol (keys %$symtab) {
        next if $symbol =~ /\A[^:]+::\z/;
        delete $symtab->{$symbol};
    }

    my $inc_file = join( '/', split /(?:'|::)/, $class ) . '.pm';
    delete $INC{ $inc_file };

    return 1
}

1
