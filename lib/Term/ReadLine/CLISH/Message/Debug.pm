package Term::ReadLine::CLISH::Message::Debug;

use Moose;
use namespace::autoclean;
use common::sense;

extends 'Term::ReadLine::CLISH::Message';

has qw(+format default) => "%% %C(black)DEBUG %s%C";
has qw(+msg default) => sub {
    my $e = $@;
    $e =~ s/\s+at\s+\(eval\s+\d+\)\s+line \d+\.//;
    $e
};

__PACKAGE__->meta->make_immutable;

1;
