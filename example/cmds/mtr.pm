package example::cmds::mtr;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;

use Net::IP;
use IPC::System::Simple 'systemx';
use common::sense;

command( isa => "example::cmds::ping",
    help => "trace route and ping combined into a neat ncurses display",
    arguments => [
        required_argument(
            target => ['validate_ipv4', 'validate_ipv6', 'validate_hostname'],
            tag_optional=>1, help => "target host for the pings" ),

        optional_argument( count => 'validate_positive_nonzero',
            help => "after this many cycles, exit normally" ),

        optional_argument( interval => 'validate_positive_nonzero',
            help => "wait this many seconds between waves" ),

        optional_argument( size => 'validate_positive_nonzero', help => "ping size (bytes)" ),
    ],
);

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;
    my $opts = shift;
    my @args = ( "--show-ips", $opts->{target}->value->ip);

    push @args, '--report-cycles' => $opts->{count}->value    if $opts->{count}->has_value;
    push @args, '--interval'      => $opts->{interval}->value if $opts->{interval}->has_value;
    push @args, '--psize'         => $opts->{size}->value     if $opts->{size}->has_value;

    return eval { systemx( mtr => @args ); 1};
}

1;
