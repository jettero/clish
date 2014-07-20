package Term::ReadLine::CLISH::Message::TODO;

use Moose;
use namespace::autoclean;
use common::sense;

extends 'Term::ReadLine::CLISH::Message';

has qw(+format default) => "%C(todo)XXX: %s";

__PACKAGE__->meta->make_immutable;

1;

