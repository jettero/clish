package example::cmds::ping;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;

use Net::DNS;
use Net::IP;
use IPC::System::Simple 'systemx';
use Term::ReadLine::CLISH::MessageSystem;
use common::sense;

command(
    help => "send icmp echo requests to a host",
    arguments => [
        optional_argument( count => 'validate_positive_nonzero',
            help => "number of packets to send" ),

        optional_argument( size  => 'validate_positive_nonzero',
            help => "size of the packets in bytes" ),

        optional_argument( df => undef, help => "set the don't fragment bit" ),

        required_argument(
            target => ['validate_ipv4', 'validate_ipv6', 'validate_hostname'],
            tag_optional=>1, help => "target host for the pings" ),
    ],
);

has qw'resolver is rw isa Net::DNS::Resolver';

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;
    my $opts = shift;

    my @args = ($opts->{target}->value->ip);

    push @args, -c => $opts->{count}->value if $opts->{count}->has_value;
    push @args, -s => $opts->{size}->value  if $opts->{size}->has_value;
    push @args, -M => "dont"                if $opts->{df}->has_value and $opts->{df}->value;

    debug "trying to systemx( ping => @args )" if $ENV{CLISH_DEBUG};
    eval { systemx( pingb => @args ); 1} or error "executing ping";
    return;
}

sub validate_ipv6 {
    my $this = shift;
    my $arg = shift;

    debug "validating ipv6 $arg" if $ENV{CLISH_DEBUG};

    return eval { Net::IP->new($arg) };
}

sub _err { $@ = shift; return }
sub _pd  { _err("permission denied for argument $_[0]") }

sub validate_ipv4 {
    my $this = shift;
    my $arg = shift;

    debug "validating ipv4 $arg" if $ENV{CLISH_DEBUG};

    # Don't let people ping local NAT things
    return _pd("$arg") if $arg =~ m/^10\./;
    return _pd("$arg") if $arg =~ m/^192\./;
    return _pd("$arg") if $arg =~ m/^172\./;

    # or this host
    return _pd("$arg") if $arg eq "1.2.3.4"; # also naughty

    return eval { Net::IP->new($arg) };
}

sub validate_hostname {
    my $this = shift;
    my $res  = $this->resolver || $this->resolver( Net::DNS::Resolver->new );
    my $arg  = shift;

    info "resolving hostname '$arg'";

    if ( my $query = $res->search($arg) ) {
        for my $rr ($query->answer) {
            my $type = $rr->type;

            given($type) {
                when( "A" )    {
                    my $addr = $rr->address;
                    debug "found A, return validate_ipv4($addr)" if $ENV{CLISH_DEBUG};
                    return $this->validate_ipv4($rr->address);
                }

                when( "AAAA" ) {
                    my $addr = $rr->address;
                    debug "found AAAA, return validate_ipv6($addr)" if $ENV{CLISH_DEBUG};
                    return $this->validate_ipv6($rr->address);
                }

                default { next }
            }
        }

    } else {
        _err( "host '$arg' lookup faliure: " . $res->errorstring );
    }

    _err( "host '$arg' not found" );

    return;
}

sub validate_positive_nonzero_number {
    my $this = shift;
    my $arg = 0 + shift;

    return $arg if $arg > 0;
    return;
}

1;
