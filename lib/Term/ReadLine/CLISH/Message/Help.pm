package Term::ReadLine::CLISH::Message::Help;

use Moose;
use namespace::autoclean;
use common::sense;

extends 'Term::ReadLine::CLISH::Message';

has qw(+format default) => "| %s";

__PACKAGE__->meta->make_immutable;

1;

sub stringify {
    my $this = shift;
    my $that = $this->SUPER::stringify(@_);

    return "\n$that\n";
}
