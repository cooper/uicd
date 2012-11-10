# Copyright (c) 2012, Mitchell Cooper
package UIC::Parser;

use warnings;
use strict;
use utf8;
use feature 'switch';

use Data::Dumper 'Dumper';

# %current
#
# (bool)    inside_message:     true if we are in a message (within the brackets)
# (bool)    message_done:       true if the message has been parsed fully (right bracket parsed)
#
# (string)  command_name:       the name of the message command
# (bool)    command_done:       true if the command has been parsed fully (colon parsed)
#
# (bool)    inside_parameter:   true if we are in a parameter value (within the parentheses)
# (string)  parameter_name:     the name of the parameter being parsed
# (string)  parameter_value:    the value of the parameter being parsed (inside parentheses)
# (bool)    parameter_escape:   true if the last character was an escape character


# %final
# (string)  command_name:       the name of the message command
# (hash)    parameters:         hash of name:value parameters

sub parse_line {
    my ($line, %current, %final) = shift;
    
    CHAR: foreach my $char (split //, $line) {
    given ($char) {
        
        # space. we handle this here for simplicity, since just about everything trims spaces out.
        when (' ') {
        
            # if we are inside a parameter value, the space is accounted for.
            if ($current{inside_parameter}) {
            
                # if there is no value, set it to an empty string.
                $current{parameter_value} = q()
                if !defined $current{parameter_value};
                
                $current{parameter_value} .= $char;
            }
            
            # otherwise, we do not care about this space at all.
            
        }
        
        # left bracket - starts a message
        when ('[') { $current{inside_message} = 1 }
        
        # right bracket - ends a message
        when (']') {
        
            # if there is no command, something surely has gone wrong. ex: [] or [:]
            if (!defined $current{command_name}) {
                # illegal error. disconnect.
                return;
            }
        
            # if there is a parameter name, we have a problem.
            if (defined $current{parameter_name}) {
                # illegal error. disconnect.
                return;
            }
        
            # there might not be any parameters. at this point, the command may be done.
            # no colon is necessary if there are no parameters.
            $current{message_done} = 1;
            
            # we're done with the message.
            delete $current{inside_message};
            
        }
        
        # any other characters
        default {
        
            # we are inside a message
            if ($current{inside_message}) {
            
                # we've received the command. it could be a parameter name.
                if ($current{command_done}) {
                
                    # backslash - escape character.
                    if ($char eq '\\' && !$current{parameter_escape}) {
                        $current{parameter_escape} = 1;
                        next CHAR;
                    }
                    
                    # left parenthesis - starts a parameter's value.
                    if ($char eq '(' && !$current{parameter_escape}) {
                        
                        # if there is no parameter, something is wrong. ex: [command: (value)]
                        if (!defined $current{parameter_name}) {
                            # illegal error. disconnect.
                        }
                        
                        # start the value.
                        $current{inside_parameter} = 1;
                    }
                
                    # right parenthesis - ends a parameter's value.
                    elsif ($char eq ')' && !$current{parameter_escape}) {
                    
                        # it is legal for a parameter to lack a value or have a value of ""
                        # just saying. no reason to check if parameter_value has a length.
                        
                        # end the value.
                        $final{parameters}{$current{parameter_name}} = $current{parameter_value}; 
                        delete $current{inside_parameter};
                        delete $current{parameter_name};
                        delete $current{parameter_value};
                        
                    }
                    
                    # exclamation mark - indicates a boolean parameter. ex: [someCommand: someParameter(some value) someBool!]
                    elsif ($char eq '!' && !$current{parameter_escape} && !$current{inside_parameter}) {
                        
                        # set value to a true value (1).
                        $final{parameters}{$current{parameter_name}} = 1;
                        delete $current{parameter_name};
                        
                    }
                    
                    
                    # actual characters of the parameter name or value.
                    else {
                    
                        my $key = $current{inside_parameter} ? 'parameter_value' : 'parameter_name';
                        
                        # if the parameter name or value doesn't exist, create empty string.
                        $current{$key} = q()
                        if !defined $current{$key};
                        
                        # append the character to the parameter name or value.
                        $current{$key} .= $char;
                        
                    }
                    
                    # reset any possible escapes.
                    delete $current{parameter_escape};
                    
                }
                
                # command not yet received. it must be the command name.
                else {
                
                    # if it's a colon, we're done with the command name.
                    if ($char eq ':') {
                    
                        # if there is no command at all, something is wrong.
                        if (!defined $current{command_name}) {
                            # illegal error. disconnect. ex: [:] or [:someParameter(etc)]
                        }
                    
                        # colon received - done with command name.
                        $current{command_done} = 1;
                        $final{command_name}   = $current{command_name};
                        next CHAR;
                        
                    }
                    
                    # if the command name doesn't exist, create empty string.
                    $current{command_name} = q()
                    if !defined $current{command_name};
                    
                    # append the character to the command name.
                    $current{command_name} .= $char;
                    
                }
            }
            
            # not inside of a message; illegal!
            else {
                # disconnect.
            }
                
            
        }
    } 
    }
    
    return \%final;
}

my $string = '[command: parameter(value) otherParameter(other value) somethingElse(they can have \(parenthesis\) in them.) someBool!]';

print Dumper parse_line($string);

