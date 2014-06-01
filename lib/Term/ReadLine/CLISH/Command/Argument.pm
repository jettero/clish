
package Term::ReadLine::CLISH::Command::Argument;

use Moose;
use Memoize;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use Moose::Util::TypeConstraints;
use Term::ReadLine::CLISH::MessageSystem;
use common::sense;
use overload '""' => \&stringify, fallback => 1;
use Carp;

subtype 'FunctionName', as 'Str', where { m/^(?:::|[\w\d_]+)*\z/ };
subtype 'ChoiceOfFunctions', as 'ArrayRef[FunctionName]';
coerce 'ChoiceOfFunctions', from 'FunctionName', via { [ $_ ] };
coerce 'ChoiceOfFunctions', from 'Undef', via { [] };

has qw(name is ro isa Str default) => "??";
has qw(validators is ro isa ChoiceOfFunctions coerce 1 default), sub { [] };
has qw(context is rw isa Term::ReadLine::CLISH::Command);
has qw(required is ro isa Bool default 0);
has qw(tag_optional is ro isa Bool default 0);
has qw(help is ro isa Str default ??);

has qw(default is ro isa Str default ??);
has qw(value is rw predicate has_value clearer no_value);
has qw(token is rw predicate has_token clearer no_token);

__PACKAGE__->meta->make_immutable;

sub stringify {
    my $this = shift;
    my $arg = "ARG[" . $this->name . "]";

    $arg .= "T<" . $this->token . ">" if $this->has_token;
    $arg .= "{HV}" if $this->has_value; # not all values are stringy, just mention that we have one

    return $arg;
}

sub value_or_default {
    my $this = shift;
    my $that = $this->value // $this->default;

    return $that;
}

sub copy_with_token {
    my $this = shift;
    my $obj  = bless { %$this }, ref $this;
    my $tok  = shift;

    $obj->token( $tok );

    return $obj;
}

sub add_copy_with_token_to_hashref {
    my $this = shift;
    my $ref  = shift; croak unless ref $ref eq "HASH";
    my $obj  = $this->copy_with_token( @_ );

    return $ref->{ $obj->name } = $obj;
}

sub copy_with_context {
    my $this = shift;
    my $obj  = bless { %$this }, ref $this;
    my $ctx  = shift;

    $obj->context( $ctx );

    return $obj;
}

sub validate {
    my ($this, $that, %vopt) = @_;
    my $validators = $this->validators;

    # default to final validation: require explicit argument to use heuristics
    $vopt{final_validation}   = $vopt{full_validation}      = !($vopt{initial_validation} || $vopt{heuristic_validation});
    $vopt{initial_validation} = $vopt{heuristic_validation} = !($vopt{final_validation} || $vopt{full_validation});

    # If there are no validators, then we can't accept arguments for this tag
    die "incomplete argument specification (no validators)" if @$validators == 0;

    my $context = $this->context or die "my context is missing";

    $that //= $this->token;
    croak "precisely what are we validating here?" unless $that;

    debug "validating $context $this" . ($vopt{final_validation} ? " (final validation)" : " (initial validation)") if $ENV{CLISH_DEBUG};

    for my $v (@$validators) {
        if( my $r = $context->$v( $that, %vopt ) ) {
            debug "validated!" if $ENV{CLISH_DEBUG};
            $this->value( $r )    if $vopt{final_validation};
            $this->token( $that ) if $vopt{initial_validation};
            return 1;
        }
    }

    return;
}

memoize( 'validate' );

1;
