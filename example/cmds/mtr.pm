package example::cmds::mtr;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;

use Net::IP;
use IPC::System::Simple 'systemx';
use common::sense;

command( name => 'mtr', isa => "example::cmds::ping",
    help => "trace route and ping combined into a neat ncurses display",
    arguments => [
        required_argument(
            target => ['validate_ipv4', 'validate_ipv6', 'validate_hostname'],
            tag_optional=>1, help => "target host for the pings" ),

        optional_argument( count => 'Scalar::Util::looks_like_number',
            help => "after this many cycles, exit normally" ),

        optional_argument( interval => 'Scalar::Util::looks_like_number',
            help => "wait this many seconds between waves" ),

        optional_argument( size => 'Scalar::Util::looks_like_number', help => "ping size (bytes)" ),
    ],
);

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;
    my $opts = shift;
    my @args = ( "--show-ips", $opts->{target});

    push @args, '--report-cycles' => $opts->{count}    if defined $opts->{count};
    push @args, '--interval'      => $opts->{interval} if defined $opts->{interval};
    push @args, '--psize'         => $opts->{size}     if defined $opts->{size};

    return eval { systemx( mtr => @args ); 1};
}

1;
