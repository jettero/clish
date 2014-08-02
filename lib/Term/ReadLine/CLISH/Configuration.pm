package Term::ReadLine::CLISH::Configuration;

use Moose;
use File::Slurp;
use File::Spec;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use common::sense;

has qw(filename is rw isa Str default) => "startup-config";
has qw(slots is ro isa HashRef default) => sub { +{} };

__PACKAGE__->meta->make_immutable;

sub read_configuration {
    my $this = shift;

    todo "read and execute configuration here";
}

sub set {
    my $this = shift;
    my ($slot, $line) = @_;

    debug "configuration set($slot => $line)" if $ENV{CLISH_DEBUG};

    return $this->slots->{slot} = $line;
}

sub clear_slot {
    my $this = shift;
    my ($slot) = @_;

    debug "configuration clear($slot)" if $ENV{CLISH_DEBUG};

    return delete $this->slots->{slot};
}

1;
