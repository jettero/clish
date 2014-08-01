package Term::ReadLine::CLISH::Configuration;

use Moose;
use common::sense;
use File::Slurp;
use File::Spec;

has qw(filename is rw isa Str default) => "startup-config";
has qw(context is rw required 1 isa Term::ReadLine::CLISH weak_ref 1);
has qw(slots is ro isa HashRef default) => sub { +{} };

__PACKAGE__->meta->make_immutable;

sub set {
    my $this = shift;
    my ($slot, $cmd, $args) = @_;
    my @words = ($cmd->name);
    for my $k (sort keys %{ $args }) {
        if( $args->{$k}->is_flag ) {
            push @words, $args->{$k}->name;
        
        } else {
            push @words, $args->{$k}->name, $args->{$k}->value;
        }
    }

    return $this->slots->{slot} = "@words";
}

sub clear_slot {
    my $this = shift;
    my ($slot, $cmd, $args) = @_;

    return delete $this->slots->{slot};
}

1;
