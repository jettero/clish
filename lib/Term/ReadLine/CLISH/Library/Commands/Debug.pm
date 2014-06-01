package Term::ReadLine::CLISH::Library::Commands::Debug;

use Term::ReadLine::CLISH::Command::Moose;
use Term::ReadLine::CLISH::MessageSystem;
use namespace::autoclean;
use common::sense;

command(
    help => "turn debugging on or off",
    arguments => [
        optional_argument(  on => undef, help => "turn debugging on" ),
        optional_argument( off => undef, help => "turn debugging off" ),
    ],
);

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;
    my $opts = shift;

       if(  $opts->{on}->has_value ) { $ENV{CLISH_DEBUG} = 1 }
    elsif( $opts->{off}->has_value ) { $ENV{CLISH_DEBUG} = 0 }

    else { $ENV{CLISH_DEBUG} = $ENV{CLISH_DEBUG} ? 0 : 1 }

    info "debugging set to " . ($ENV{CLISH_DEBUG} ? "on" : "off");

    return;
}

1;
