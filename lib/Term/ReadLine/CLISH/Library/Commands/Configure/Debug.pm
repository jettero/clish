package Term::ReadLine::CLISH::Library::Commands::Configure::Debug;

use Term::ReadLine::CLISH::Command::Moose;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use namespace::autoclean;
use common::sense;

command(
    help => "turn debugging on, off, or toggle",
    arguments => [
        flag( 'on',  help => "turn debugging on"  ),
        flag( 'off', help => "turn debugging off" ),
    ],

    config_slot_no => 0,
    config_tags => [ 'debug' ],
);

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;
    my $opts = shift;

    my $orig = $ENV{CLISH_DEBUG};

       if(  $opts->{on}->flag_present ) { $ENV{CLISH_DEBUG} = 1 }
    elsif( $opts->{off}->flag_present ) { $ENV{CLISH_DEBUG} = 0 }

    else {
        if( $ENV{CLISH_DEBUG} ) {
            $ENV{CLISH_DEBUG} = 0;
            $opts->{off}->set_value(1);

        } else {
            $ENV{CLISH_DEBUG} = 1;
            $opts->{on}->set_value(1);
        }
    }

    info "debugging set to " . ($ENV{CLISH_DEBUG} ? "on" : "off")
        if $orig xor $ENV{CLISH_DEBUG};

    return;
}

1;
