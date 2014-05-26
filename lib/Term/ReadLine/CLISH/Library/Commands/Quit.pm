package Term::ReadLine::CLISH::Library::Commands::Quit;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use common::sense;

extends 'Term::ReadLine::CLISH::Command';

command( help => "exit this shell" );

__PACKAGE__->meta->make_immutable;

sub exec {
    exit 0
}

1;
