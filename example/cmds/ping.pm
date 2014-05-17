package example::cmds::ping;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;

use Net::IP;
use IPC::System::Simple 'systemx';
use Scalar::Util qw(looks_like_number);

command( name => 'ping',
    help => "send icmp echo requests to a host",
    arguments => [
        required_argument(
            target => ['validate_ipv4', 'validate_ipv6', 'validate_hostname'],
            tag_optional=>1, help => "target host for the pings" ),

        optional_argument( count => 'Scalar::Util::looks_like_number',
            help => "number of packets to send" ),

        optional_argument( size  => 'Scalar::Util::looks_like_number',
            help => "size of the packets in bytes" ),

        optional_argument( df => undef, help => "set the don't fragment bit" ),
    ],
);

__PACKAGE__->meta->make_immutable;

sub cmd_ping {
   my $target = shift; # this is validated already
   my %opts => shift;

   my @args;
   push @args, -c => $opts{count} if defined $opts{count};
   push @args, -s => $opts{size}  if defined $opts{size};
   push @args, -M => "dont"       if defined $opts{df};

   return eval { systemx( ping => $target, @args ); 1};
}

sub validate_ipv6 {
   my $arg = shift;

   return eval { Net::IP->new($arg) };
}

sub validate_ipv4 {
   my $arg = shift;

   # Don't let people ping local NAT things
   return if $arg =~ m/^10\./;
   return if $arg =~ m/^192\./;
   return if $arg =~ m/^172\./;

   # or this host
   return if $arg eq "1.2.3.4"; # also naughty

   return eval { Net::IP->new($arg) };
}

1;
