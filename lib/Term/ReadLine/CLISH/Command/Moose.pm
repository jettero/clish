
package Term::ReadLine::CLISH::Command::Moose;

use Moose ();
use Moose::Exporter;
use Term::ReadLine::CLISH::Command::Argument;
use common::sense;
use Carp;

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

    my $class = $options{isa} || "Term::ReadLine::CLISH::Command";
    $meta->superclasses( $class );

    my $i = 0;
    my ($package) = caller($i);
    while( $package =~ m/^Moose::/ ) {
        ($package) = caller(++$i);
    }

    my $name = $options{name} || lc( (split "::", $package)[-1] );

    $meta->add_attribute( qw(+name      default) => $name );
    $meta->add_attribute( qw(+help      default) => $options{help} )   if exists $options{help};
    $meta->add_attribute( qw(+arguments default), sub { [@def_arg] } ) if exists $options{arguments};
}

sub argument {
    my $name       = shift;
    my $validators = shift;
    my %options    = @_;

    croak "argument name must not contain any characters that don't belong in function names (\\w\\_\\d)"
        if $name =~ m/[^\w\_\d]/;

    my $arg = Term::ReadLine::CLISH::Command::Argument->new(name=>$name, validators=>$validators, %options);
        croak "please provide at least one validator for '$name' or require a tag (which can then represent a switch true value)"
        if $arg->tag_optional and not @{ $arg->validators };

    return $arg;
}

sub required_argument {
    argument( @_, required => 1 );
}

sub optional_argument {
    argument( @_, required => 0 );
}

1;
