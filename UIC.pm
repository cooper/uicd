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

1
