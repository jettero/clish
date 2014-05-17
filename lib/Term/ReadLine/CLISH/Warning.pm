package Term::ReadLine::CLISH::Warning;

use Moose;
use namespace::autoclean;
use common::sense;

has qw(error is ro isa Str default), sub {
    my $e = $@;
    $e =~ s/\s+at\s+\(eval\s+\d+\)\s+line \d+\.//;
    $e
};

__PACKAGE__->meta->make_immutable;

sub spew {
    my $this = shift;
    my $msg = shift;

    say "WARNING $msg: " . $this->error;
}

1;
