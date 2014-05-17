package example::myshell;

use Moose;
use common::sense;
use namespace::autoclean;

extends "Term::ReadLine::CLISH";

has qw(+prompt default) => "myshell> ";
has qw(+prefix default) => "example::myshell::cmds";
has qw(+path   default) => sub { ['example/cmds', @INC] };

__PACKAGE__->meta->make_immutable;

1;
