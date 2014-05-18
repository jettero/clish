package Term::ReadLine::CLISH::Library::Commands::Quit;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use common::sense;

command( name => 'quit',
    help => "exit the shell",
);

__PACKAGE__->meta->make_immutable;

sub cmd_quit {
    exit 0
}

1;
