# Copyright (c) 2012, Mitchell Cooper
# UICd::Connection: represents a connection to a UIC server.
# Connections may be associated with a specific user, but by no means do they have to be.
package UICd::Connection;

use warnings;
use strict;
use utf8;
use parent 'UIC::EventedObject';

1
