package Term::ReadLine::CLISH::Message::Information;

use Moose;
use namespace::autoclean;
use common::sense;

extends 'Term::ReadLine::CLISH::Message';

has qw(+format default) => "%% %s";

__PACKAGE__->meta->make_immutable;

1;
