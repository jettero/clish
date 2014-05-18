package Term::ReadLine::CLISH::Error;

use Moose;
use namespace::autoclean;
use common::sense;

has qw(output_prefix is ro isa Str default) => "% ";
has qw(error is ro isa Str default), sub {
    my $e = $@;
    $e =~ s/\s+at\s+\(eval\s+\d+\)\s+line \d+\.//;
    $e
};

__PACKAGE__->meta->make_immutable;

sub spew {
    my $this = shift;
    my $msg = shift;

    say $this->output_prefix . "ERROR $msg: " . $this->error;
}

1;
