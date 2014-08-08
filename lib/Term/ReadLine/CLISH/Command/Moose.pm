
package Term::ReadLine::CLISH::Command::Moose;

use Moose ();
use Moose::Exporter;
use Term::ReadLine::CLISH::Command::Argument;
use common::sense;
use Carp;

Moose::Exporter->setup_import_methods(
    with_meta => [ qw(command) ],
    as_is     => [ qw(required_argument optional_argument argument flag) ],
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

    if( exists $options{config_tags} ) {
        my @def_tags = @{$options{config_tags}};

        $meta->add_attribute( qw(+config_slot_no default) => $options{config_slot_no}||0 );
        $meta->add_attribute( qw(+config_tags    default) => sub { [@def_tags] } );
    }

    if( my @a = grep {defined} ($options{alias}, eval {@{ $options{aliases} }}) ) {
        $meta->add_attribute( qw(+aliases default) => sub { [@a] } );
    }

    if( exists $options{uses_pager} ) {
        $meta->add_attribute( qw(+uses_pager default), !!$options{uses_pager} );
    }

    if( exists $options{argument_options} ) {
        my %aa = %{ $options{argument_options} };
        $meta->add_attribute( qw(+argument_options default) => sub { +{ %aa } } );
    }

    if( $options{positional_args} ) {
        $meta->add_attribute( qw(+positional_args default) => 1 );
    }
}

sub argument {
    my $name       = shift;
    my $validators = shift;
    my %options    = @_;

    # XXX: I removed this long after I forgot why I had it ... what whas it's purpose??
#   croak "argument name must not contain any characters that don't belong in function names (\\w\\_\\d)"
#       if $name =~ m/[^\w\_\d]/;

    $validators = [] if not defined $validators;

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

sub flag {
    my $flag = shift;

    argument( $flag => undef, @_, required => 0, is_flag => 1 );
}

1;
