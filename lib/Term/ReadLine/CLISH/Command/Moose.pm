
package Term::ReadLine::CLISH::Command::Moose;

use Moose ();
use Moose::Exporter;
use common::sense;
use Term::ReadLine::CLISH::Command::Option;
use Moose::Util::TypeConstraints;
use Carp;

subtype 'Option', as 'Term::ReadLine::CLISH::Command::Option';

Moose::Exporter->setup_import_methods(
    with_meta => [ qw(command) ],
    as_is     => [ qw(required_argument optional_argument argument) ],
    also      => 'Moose'
);

sub command {
    my $meta = shift;
    my %options = @_;

    my @def_arg = @{$options{arguments} || []};

    # warn "$meta";
    # Moose::Meta::Class

    croak "command name must not contain any characters that don't belong in function names (\\w\\_\\d)"
        if $options{name} =~ m/[^\w\_\d]/;

    $meta->add_attribute( qw(name is ro isa Str default) => $options{name} );
    $meta->add_attribute( qw(help is ro isa Str default) => $options{help} || "??" );
    $meta->add_attribute( qw(arguments is ro isa ArrayRef[Option] default), sub { [@def_arg] } );
    $meta->superclasses("Term::ReadLine::CLISH::Command");
}

sub argument {
    my $name       = shift;
    my $validators = shift;
    my %options    = @_;

    croak "argument name must not contain any characters that don't belong in function names (\\w\\_\\d)"
        if $name =~ m/[^\w\_\d]/;

    return Term::ReadLine::CLISH::Command::Option->new(name=>$name, validators=>$validators, %options);
}

sub required_argument {
    argument( @_, required => 1 );
}

sub optional_argument {
    argument( @_, required => 0 );
}

1;
