# Copyright (c) 2012, Mitchell Cooper
# UICd::Configuration: represents a configuration file.
#
# Events:
# each time a configuration value changes, change_BLOCKTYPE_BLOCKNAME_KEY is fired with the new and old values.
# for example a change of oper:cooper:password would fire change_oper_cooper_password(oldpassword, newpassword).
# the event is fired AFTER the actual value is changed.
#
package UICd::Configuration;

use warnings;
use strict;
use utf8;
use parent 'UIC::EventedObject';

# create a new configuration instance.
sub new {
    my ($class, $hashref, $filename) = @_;
    return bless {
        conf     => $hashref,
        filename => $filename
    }, $class;
}

# parse the configuration file.
sub parse_config {
    my ($conf, $i, $block, $name, $key, $val, $config) = shift;
    open $config, '<', $conf->{filename} or return;
    
    while (my $line = <$config>) {

        $i++;
        $line = UICd::Utils::trim($line);
        next unless $line;
        next if $line =~ m/^#/;

        # a block with a name.
        if ($line =~ m/^\[(.*?):(.*)\]$/) {
            $block = UICd::Utils::trim($1);
            $name  = UICd::Utils::trim($2);
        }

        # a nameless block.
        elsif ($line =~ m/^\[(.*)\]$/) {
            $block = 'section';
            $name  = UICd::Utils::trim($1);
        }

        # a key and value.
        elsif ($line =~ m/^(\s*)(\w*)=(.*)$/ && defined $block) {
            $key = UICd::Utils::trim($2);
            $val = eval UICd::Utils::trim($3);
            die "Invalid value in $$conf{filename} line $i: $@\n" if $@;
            
            # the value has changed, so send the event.
            if (!exists $conf->{conf}{$block}{$name}{$key} ||
                $conf->{conf}{$block}{$name}{$key} ne $val) {
                my $old = $conf->{conf}{$block}{$name}{$key} = $val;
                $conf->fire_event("change_${block}_${name}_${key}" => $old, $val);
            }
            
        }

        # I don't know how to handle this.
        else {
            die "Invalid line $i of $$conf{filename}\n";
        }

    }
    
    return 1;
}


1
