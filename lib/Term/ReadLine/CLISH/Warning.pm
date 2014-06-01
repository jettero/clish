package Term::ReadLine::CLISH::Warning;

use Moose;
use namespace::autoclean;
use common::sense;

extends 'Term::ReadLine::CLISH::Message';

has qw(+format default) => "%% %C(yellow)WARNING%C %s";
has qw(+msg default) => sub {
    my $e = $@; undef $@; # we eat $@'s
    $e =~ s/\s+at\s+\(eval\s+\d+\)\s+line \d+\.//;
    $e
};

__PACKAGE__->meta->make_immutable;

1;
