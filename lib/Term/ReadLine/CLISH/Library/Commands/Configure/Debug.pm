package Term::ReadLine::CLISH::Library::Commands::Configure::Debug;

use Term::ReadLine::CLISH::Command::Moose;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use namespace::autoclean;
use common::sense;

command(
    help => "turn debugging on or off",
    arguments => [
        flag( 'on',  help => "turn debugging on",  cmd_mod => '+'  ),
        flag( 'off', help => "turn debugging off", cmd_mod => '!-' ),
    ],
);

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;
    my $opts = shift;

       if(  $opts->{on}->flag_present ) { $ENV{CLISH_DEBUG} = 1 }
    elsif( $opts->{off}->flag_present ) { $ENV{CLISH_DEBUG} = 0 }

    else { $ENV{CLISH_DEBUG} = $ENV{CLISH_DEBUG} ? 0 : 1 }

    info "debugging set to " . ($ENV{CLISH_DEBUG} ? "on" : "off");

    return;
}

1;
