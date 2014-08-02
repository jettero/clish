package Term::ReadLine::CLISH::Configuration;

use Moose;
use File::Slurp;
use File::Spec;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use common::sense;

has qw(filename is rw isa Str default) => "startup-config";
has qw(context is rw required 1 isa Term::ReadLine::CLISH weak_ref 1);
has qw(slots is ro isa HashRef default) => sub { +{} };

__PACKAGE__->meta->make_immutable;

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
