package Term::ReadLine::CLISH::Error;

use Moose;
use namespace::autoclean;
use common::sense;

extends 'Term::ReadLine::CLISH::Message';

has qw(+format default) => "%% %C(red)ERROR%C %s";
has qw(+msg default) => sub {
    my $e = $@;
    $e =~ s/\s+at\s+\(eval\s+\d+\)\s+line \d+\.//;
    $e
};

__PACKAGE__->meta->make_immutable;

1;

