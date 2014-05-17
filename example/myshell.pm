package example::myshell;

use Moose;
use common::sense;
use namespace::autoclean;
use Term::ReadLine::CLISH;

extends "Term::ReadLine::CLISH";

has qw(+prompt default) => "myshell> ";
has qw(+prefix default) => "example::cmds";
has qw(+path   default) => sub { ['example/cmds', @INC] };

__PACKAGE__->meta->make_immutable;

1;
