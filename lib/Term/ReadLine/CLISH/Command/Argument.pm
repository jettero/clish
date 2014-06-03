
package Term::ReadLine::CLISH::Command::Argument;

use Moose;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use Moose::Util::TypeConstraints;
use Term::ReadLine::CLISH::MessageSystem;
use common::sense;
use overload '""' => \&stringify, fallback => 1;
use Carp;

subtype 'FunctionName', as 'Str', where { m/^(?:::|[\w\d_]+)*\z/ };
subtype 'ChoiceOfFunctions', as 'ArrayRef[FunctionName]';

subtype "CommandMod", as "Str", where { m/^[!+-]*\z/ };

coerce 'ChoiceOfFunctions', from 'FunctionName', via { [ $_ ] };
coerce 'ChoiceOfFunctions', from 'Undef', via { [] };

has qw(name is ro isa Str default) => "??";
has qw(validators is ro isa ChoiceOfFunctions coerce 1 default), sub { [] };
has qw(context is rw isa Term::ReadLine::CLISH::Command);
has qw(required is ro isa Bool default 0);
has qw(tag_optional is ro isa Bool default 0);
has qw(help is ro isa Str default ??);

has qw(default is ro isa Str default ??);
has qw(value is rw predicate has_value clearer no_value reader value writer _wvalue);
has qw(token is rw predicate has_token clearer no_token reader token writer _wtoken);
has qw(cmd_mod is rw isa CommandMod predicate has_cmd_mod);
has qw(is_flag is rw isa Bool);

__PACKAGE__->meta->make_immutable;

sub flag_present {
    my $this = shift;
    croak "$this isn't a flag" unless $this->is_flag;
    return $this->has_value;
}

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

sub copy_with_value {
    my $this = shift;
    my $obj  = bless { %$this }, ref $this;
    my $val  = shift;

    $obj->_wvalue( $val );

    return $obj;
}

sub copy_with_token {
    my $this = shift;
    my $obj  = bless { %$this }, ref $this;
    my $tok  = shift;

    $obj->_wtoken( $tok );

    return $obj;
}

sub validate_copy_with_value_to_hashref {
    my $this = shift;
    my $ref  = shift; croak unless ref $ref eq "HASH";

    my $final_value = $this->validate($this->token, final_validation=>1);
    return $ref->{ $this->name } = undef unless $final_value;
    return $ref->{ $this->name } = $this->copy_with_value( $final_value );
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

    if( $this->is_flag ) {
      # NOTE: this is really more of a parser thing to check… Here, we just
      # assume this croak wouldn't ever come up.
      #
      # croak "the token should be roughly equivalent to the tag for a flag"
      #     unless substr($this->name, 0, length $that) eq $that;

      return 1; # anyway, the flag is present, so say so to anyone that asked

    } else {
        # If there are no validators, then we can't accept arguments for this tag
        die "incomplete argument specification (no validators)" if @$validators == 0;
        croak "precisely what are we validating here?" unless $that;
    }

    my $context = $this->context or die "my context is missing";

    debug "validating $context $this tok=$that" . ($vopt{final_validation} ? " (final validation)" : " (initial validation)") if $ENV{CLISH_DEBUG};

    my $i_da; # inside [eval] dollar-sign-at
    for my $v (@$validators) {
        my $r;

        unless( eval { $r = $context->$v( $that, %vopt ); $i_da = $@; 1} ) {
            my $class = ref $this;
            my @vopt = %vopt;
            warning "(internal) in $class —> $v($that, @vopt)";
            next;
        }

        if( $r ) {
            if( $vopt{final_validation} ) {
                debug "validated $context $this tok=$that (final validation)" if $ENV{CLISH_DEBUG};
                return $r;
            }

            debug "validated $context $this tok=$that (initial validation)" if $ENV{CLISH_DEBUG};
            return 1;
        }
    }

    if( $vopt{final_validation} ) {
        if( scrub_last_error($i_da) ) {
            error "with $this";

        } else {
            error "with $this", "argument does not seem correct (condition uknown)";
        }
    }

    return;
}

1;
