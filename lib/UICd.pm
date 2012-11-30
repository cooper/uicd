# Copyright (c) 2012, Mitchell Cooper
# UICd: reprents a server instance.
# inherits from UIC, which represents a UIC object.
# (manages users, servers, channels, and more.)
package UICd;

use warnings;
use strict;
use utf8;

use UICd::Utils qw(log2 fatal gv set increase_level decrease_level);

our ($VERSION, @ISA) = 1;

# the values %lGV are used as defaults if any of
# the keys do not exist when UICd.pm is loaded.
#
# it is safe to extend this from version to version, as start()
# ensures that each of these values are present after UICd.pm is loaded.
my %lGV = (
    
    # software-related variables.
    NAME    => 'uicd',
    VERSION => $VERSION,
    PROTO   => 1,
    START   => time,
    NOFORK  => 'NOFORK' ~~ @ARGV,
    
    # variables that need to be set to a zero value.
    connection_count      => 0,
    max_connection_count  => 0,
    max_global_user_count => 0,
    max_local_user_count  => 0,
    log_level             => 0
    
);

##############################
### CALLED BY MAIN PACKAGE ###
##############################

# BEGIN block.
sub begin {
    %main::GV = %lGV;
}

# boot server. only called during initial start.
sub boot {

    log2('booting server');
    increase_level();
    
    # set up UICd.
    start();

    # create the IO::Async loop.
    log2('creating IO::Async loop');
    $main::loop = IO::Async::Loop->new unless $main::loop;

    # create the main UICd object.
    log2('creating libuic UIC manager');
    increase_level();
    
    $main::UICd = $UIC::main_uic = $main::GV{UICd} = __PACKAGE__->new();
 
    decrease_level();
    log2('done creating UIC manager');

    # create this server's object.
    log2('creating local server '.$main::conf->get('server', 'name'));
    increase_level();

    $main::server = $main::GV{server} = $main::UICd->new_server(
        name         => $main::conf->get('server', 'name'),
        network_name => $main::conf->get('server', 'network_name'),
        id           => $main::conf->get('server', 'id'),
        description  => $main::conf->get('server', 'description'),
        software     => gv('NAME'),
        version      => gv('VERSION')
    );
    
    decrease_level();
    log2('done creating server');
     
    # load API and configuration modules.
    if ($main::conf->get('enable', 'API')) {
        require API;
                
        # API::Module constants.
        sub API::Module::t_boolean () { 'boolean'}
        sub API::Module::t_string  () { 'string' }
        sub API::Module::t_number  () { 'number' }
        sub API::Module::t_server  () { 'server' }
        sub API::Module::t_user    () {  'user'  }
        
        @API::Module::EXPORT = qw(t_boolean t_string t_number t_server t_user);
        
        # create the API manager.
        $main::API = API->new(
            log_sub  => \&api_log,
            mod_dir  => $main::dir{mod},
            base_dir => "$main::dir{lib}/API/Base"
        );

        log2('Loading configuration modules');
        increase_level();
        
        foreach my $module ($main::conf->keys_of_block('modules')) {
            $main::API->load_module($module);
        }
        
        decrease_level();
        log2('Done loading modules');
        
    }

    # create the sockets and begin listening.
    create_sockets();

    decrease_level();
    log2('done booting server');
    
}

############################
### STARTING & RELOADING ###
############################

# loads up everything needed for UICd. called in boot(), as it loads dependencies.
# keep in mind that this may be called more than once.
# unlike boot(), it is called after UICd.pm is loaded, even if it was reloaded.
sub start {

    log2('setting up UICd');
    increase_level();
    
    # base requirements.
    require POSIX;
    
    # IO::Async and friends.
    require IO::Async::Loop;
    require IO::Async::Listener;
    require IO::Async::Timer::Periodic;
    require IO::Async::Stream;
    require IO::Socket::IP;

    # libuic and UICd.
    require UIC;
    require UICd::Connection;
    require UICd::Server;
    require UICd::User;
    require UICd::Channel;
    
    # Evented::Configuration.
    require Evented::Configuration;
    
    
    # become a child of UIC.
    unshift @ISA, 'UIC' unless 'UIC' ~~ @ISA;
    
    # set default global variables if they are not already present.
    foreach my $var (keys %lGV) {
        next if exists $main::GV{$var};
        $main::GV{$var} = $lGV{$var};
    }
    
    # load the configuration. we can do this as many times as we please.
    my $file = "$main::dir{etc}/uicd.conf";
    log2("loading uicd configuration $file");
    $main::conf = $main::GV{conf} = Evented::Configuration->new(\%main::conf, $file);
    $main::conf->parse_config or die "Can't parse $file: $!\n";
    
    # replace reloadable().
    *main::reloadable = *reloadable;
    
    # become a daemon
    become_daemon() unless $main::GV{NOFORK};
    
    # register package as reloadable.
    main::reloadable(
        before => sub { *main::TEMP_LOG = *log2 },
        after  => sub { undef *main::TEMP_LOG }
    );
    
    decrease_level();
    log2('setup complete');
}

# do the reloading. it is dangerous to call any external subroutines from here,
# as it may be reloading this package itself.
sub RELOAD {
    log2('RELOADING UICd!');
    my $starttime = time;
    foreach my $pkg (@main::reloadable) {
    
        # before callback.
        $pkg->{before}() if $pkg->{before};
        
        # this must be called here, as it is defined in before callback.
        main::TEMP_LOG("reloading package '$$pkg{name}'");
        
        # unload it. from Class::Unload on CPAN. Copyright (c) 2011, Dagfinn Ilmari MannsÃ¥ker.
        my $class = $pkg->{name};
        my $inc_file = join( '/', split /(?:'|::)/, $class ) . '.pm';
        (sub {
            no strict 'refs';

            # flush inheritance caches
            @{$class . '::ISA'} = ();

            my $symtab = $class.'::';
            # delete all symbols except other namespaces
            for my $symbol (keys %$symtab) {
                next if $symbol =~ /\A[^:]+::\z/;
                delete $symtab->{$symbol};
            }

            delete $INC{ $inc_file };
            
            use strict 'refs';
        })->();
        
        
        # during callback.
        $pkg->{during}() if $pkg->{during};
        
        # load it.
        require $inc_file;
        
        # this must be called here, as it is undefined in after callback.
        main::TEMP_LOG("package '$$pkg{name}' reloaded successfully");
        
        # call after.
        $pkg->{after}() if $pkg->{after};
        
    }
    my $finishtime = time;
    my $diff = $finishtime - $starttime;
    log2('finished reloading UICd in '.(!$diff ? 'less than one second' : $diff.' second'.($diff == 1 ? '' : 's')));
}

# main::reloadable(
#     before  => sub { ... }, # called before unloaded
#     during  => sub { ... }, # called after unloaded, before loaded
#     after   => sub { ... }, # called after loaded
# );
sub reloadable {
    my $package = caller;
    my %opts    = @_;
    $opts{name} = $package;
    push @main::reloadable, \%opts;
}

#######################
### SETTING UP UICD ###
#######################

# create the sockets and begin listening. only called during initial start.
sub create_sockets {
    log2('opening sockets');
    increase_level();
    
    foreach my $addr ($main::conf->names_of_block('listen')) {
      foreach my $port (@{$main::conf->get(['listen', $addr], 'port')}) {

        # create the loop listener
        my $listener = IO::Async::Listener->new(on_stream => \&handle_connect);
        $main::loop->add($listener);

        # create the socket
        my $socket = IO::Socket::IP->new(
            LocalAddr => $addr,
            LocalPort => $port,
            Listen    => 1,
            ReuseAddr => 1,
            Type      => Socket::SOCK_STREAM(),
            Proto     => 'tcp'
        ) or fatal("Couldn't listen on [$addr]:$port: $!");

        # add to looped listener
        $listener->listen(handle => $socket);

        log2("Listening on [$addr]:$port");
    } }
    
    decrease_level();
    log2('done opening sockets');
    return 1
}

# become a daemon.
sub become_daemon {

    # unless NOFORK enabled, fork.
    if (!$main::GV{NOFORK}) {

        # since there will be no input or output from here on,
        # open the filehandles to /dev/null
        open STDIN,  '<', '/dev/null' or die;
        open STDOUT, '>', '/dev/null' or die;
        open STDERR, '>', '/dev/null' or die;

        # write the PID file that is used by the start/stop/rehash script.
        open my $pidfh, '>', "$main::dir{run}/$main::GV{NAME}.pid" or die;
        $main::GV{PID} = fork;
        say $pidfh $main::GV{PID} if $main::GV{PID};
        close $pidfh;
    }

    exit if $main::GV{PID};
    POSIX::setsid();
}

# begin the running loop.
sub loop {
    log2('starting IO::Async runtime, entering main loop');
    $main::loop->loop_forever;
}

########################
### HANDLING SIGNALS ###
########################

# stop the uicd.
sub terminate {

}

# handle a HUP.
sub signalhup {
    log2('handling HUP');
    RELOAD();
    start();
}

# handle a PIPE.
sub signalpipe {
}

# handle a warning.
sub WARNING {
    log2('[WARNING] '.shift());
}

###########################
### IO::ASYNC CALLBACKS ###
###########################

# handle a new connection.
sub handle_connect {
    my ($listener, $stream) = @_;

    # if the connection limit has been reached, drop the connection.
    if ($main::UICd->number_of_connections >= $main::conf->get('limit', 'total_local_connections')) {
        $stream->close_now;
        return;
    }

    # if the connection IP limit has been reached, drop the connection.
    my $ip = $stream->{write_handle}->peerhost;
    if (scalar(grep { $_->{ip} eq $ip } $main::UICd->connections) >= $main::conf->get('limit', 'local_connections_per_ip')) {
        $stream->close_now;
        return;
    }

    # if the global IP limit has been reached, drop the connection.
    #if (scalar(grep { $_->{ip} eq $ip } values %user::user) >= conf('limit', 'global_connections_per_ip')) {
    #    $stream->close_now;
    #    return;
    #}

    # create connection object.
    my $conn = $main::UICd->new_connection($stream);

    $stream->configure(
        read_all       => 0,
        read_len       => POSIX::BUFSIZ(),
        on_read        => \&handle_data,
        on_read_eof    => sub { $main::UICd->close_connection($conn, 'Connection closed'); $stream->close_now   },
        on_write_eof   => sub { $main::UICd->close_connection($conn, 'Connection closed'); $stream->close_now   },
        on_read_error  => sub { $main::UICd->close_connection($conn, 'Read error: ' .$_[1]); $stream->close_now },
        on_write_error => sub { $main::UICd->close_connection($conn, 'Write error: '.$_[1]); $stream->close_now }
    );

    $main::loop->add($stream);
    
    # send the initial commands.
    $conn->welcome;
    
}

# handle incoming data.
sub handle_data {
    my ($stream, $buffer) = @_;
    my $connection = $main::UICd->lookup_connection_by_stream($stream);
    while ($$buffer =~ s/^(.*?)\n//) {
        $connection->handle($1);
    }
}

############################
### MANAGING CONNECTIONS ###
############################

# create a connection and associate it with this UICd object.
sub new_connection {
    my ($uicd, $stream) = @_;
    my $connection = UICd::Connection->new($stream);
    $uicd->set_connection_for_stream($stream, $connection);
    
    # update total connection count
    my $count = gv('connection_count');
    set('connection_count', $count + 1);

    # update maximum connection count
    if ($uicd->number_of_connections + 1 > gv('max_connection_count')) {
        set('max_connection_count', $uicd->number_of_connections + 1);
    }

    return $connection;
}

# associate a connection with a stream.
sub set_connection_for_stream {
    my ($uicd, $stream, $connection) = @_;
    $uicd->{connections}{$stream} = $connection;
    return $connection;
}

# dispose of a connection.
sub remove_connection {
    my ($uicd, $connection) = @_;
    delete $uicd->{connections}{$connection->{stream}};
}

# number of current connections.
sub number_of_connections {
    my $uicd = shift;
    return scalar keys %{$uicd->{connections}};
}

# returns a list of active connections.
sub connections {
    my $uicd = shift;
    return values %{$uicd->{connections}};
}

# find a connection by its stream.
sub lookup_connection_by_stream {
    my ($uicd, $stream) = @_;
    return $uicd->{connections}{$stream};
}

# end and delete a connection.
sub close_connection {
    my ($uicd, $connection, $reason, $silent) = @_;
    log2("Closing connection from $$connection{ip}: $reason");
    $connection->done($reason, $silent);
    $uicd->remove_connection($connection);
}

#####################
### UIC OVERRIDES ###
#####################

# logging.
# this overrides UIC::log().
sub log {
    my ($uicd, $message) = @_;
    my $sub = (caller 1)[3];
    log2("[libuic] ".($sub && $sub ne '(eval)' ? "$sub():" : q([).(caller)[0].q(])).q( ).$message);
}

# parse a line of data.
# this overrides UIC::parse_data().
sub parse_data {
    my ($uicd, $data, $connection) = @_;
    log2("parsing data: $data");
    
    # first attempt to parse data as UIC.
    my $result    = UIC::Parser::parse_line($data);
    my $uic_error = $@;
    
    # if JSON/UJC support is enabled, load JSON if not already loaded
    # and attempt to parse the message as JSON.
    my ($json_error, $json_interpret_error);
    if (!$result && $main::conf->get('enable', 'JSON')) {
        require JSON if !$INC{'JSON'};
        
        # attempt to parse the JSON. must be wrapped in eval to catch errors.
        $result = eval { my $j = JSON::decode_json($data); die "$@\n" if $@; $j };
        
        # figure the error if there is one.
        $json_error = $@ if $@ && $@ ne $uic_error;
        
        # convert to proper values.
        $result = UIC::Parser::decode_json($result) if $result;
        $json_interpret_error = $@ if $@ && $@ ne $json_error;

        # strip newlines.
        $json_error =~ s/\n//g if $json_error;
        
    }
    
    # unable to parse data - drop the connection.
    if (!$result) {

        # forcibly send an error immediately.
        my $parameters                    = { uicError => $uic_error };
        $parameters->{jsonError}          = $json_error           if $json_error;
        $parameters->{jsonInterpretError} = $json_interpret_error if $json_interpret_error;
        $connection->send('syntaxError', $parameters);
        # close the connection.
        $uicd->close_connection($connection, 'Syntax error');
        return;
        
    }
     
    # the command handler $info sub.
    my $sub = sub {
        my $info = shift;
        $info->{connection}   = $connection;
        $info->{raw_data}     = $data;
        $info->{message_id}   = $result->{message_id};
        $info->{wants_return} = defined $result->{message_id};
        $info->{server}       = gv('server');
    };
    
    # process the parameters.
    my $params = $uicd->process_parameters($result->{parameters});
    
    # fire the global handlers.
    my $return = $uicd->fire_handler($result->{command_name}, $params, $sub);
    
    # if it returned nothing, try connection handlers.
    if (!$return) {
        $return = $uicd->fire_handler('connection.'.$result->{command_name}, $params, $sub);
    }
    
    # there's always the possibility that the connection was terminated inside a handler.
    return if $connection->{goodbye};
    
    # if we have a return value, send return command.
    # we have to do this the hard way because of the message identifier.
    # like connection->send, uses prepare_parameters_for_sending().
    if ($return) {
        my $reply = UIC::Parser::encode(
            message_id   => $result->{message_id},
            command_name => 'return',
            parameters   => $main::UICd->prepare_parameters_for_sending($return)
        );
        $connection->{stream}->write("$reply\n");
    }
    
    return 1;
}

#####################
### MISCELLANEOUS ###
#####################

sub api_log {
    log2('[API] '.shift());
}

1
