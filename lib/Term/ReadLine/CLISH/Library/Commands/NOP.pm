package Term::ReadLine::CLISH::Library::Commands::NOP;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use common::sense;

extends 'Term::ReadLine::CLISH::Command';

has qw'+unusual_invocation default' => 1;

command( name => 'nop',
    help => "do nothing",
);

__PACKAGE__->meta->make_immutable;

sub exec {
    exit 0
}

1;
