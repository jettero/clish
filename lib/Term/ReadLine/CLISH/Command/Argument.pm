
package Term::ReadLine::CLISH::Command::Argument;

use Moose;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use Moose::Util::TypeConstraints;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs :tool);
use common::sense;
use overload '""' => \&stringify, fallback => 1;
use Carp;

subtype 'FunctionName', as 'Str', where { m/^(?:::|[\w\d_]+)*\z/ };
subtype 'ChoiceOfFunctions', as 'ArrayRef[FunctionName]';

coerce 'ChoiceOfFunctions', from 'FunctionName', via { [ $_ ] };
coerce 'ChoiceOfFunctions', from 'Undef', via { [] };

has qw(name is ro isa Str default) => "??";
has qw'aliases is ro isa ArrayRef[Str] default' => sub {[]};
has qw(validators is ro isa ChoiceOfFunctions coerce 1 default), sub { [] };
has qw(context is rw weak_ref 1 isa Term::ReadLine::CLISH::Command);
has qw(required is ro isa Bool default 0);
has qw(tag_optional is ro isa Bool default 0);
has qw(help is ro isa Str default ??);

has qw(default is ro isa Str default ??);
has qw(value is rw predicate has_value clearer no_value reader value writer set_value);
has qw(token is rw predicate has_token clearer no_token reader token writer set_token);
has qw(is_flag is rw isa Bool);
has qw(takes_files is rw isa Bool);
has qw(before_completion is rw isa CodeRef);
has qw(after_completion is rw isa CodeRef);

__PACKAGE__->meta->make_immutable;

sub filename_completion_desired {
    my $this = shift;

    return $this->takes_files && !$this->has_token;
}

sub all_names {
    my $this = shift;
    my @names = ( $this->name, @{$this->aliases} );
    return wantarray ? @names : \@names;
}

sub token_matches {
    my $this = shift;
    my $tok  = shift;

    if( $tok ) {
        for($this->all_names) {
            return 1 if substr($_, 0, length $tok) eq $tok;
        }
    }

    return;
}

sub flag_present {
    my $this = shift;
    croak "$this isn't a flag" unless $this->is_flag;
    return $this->has_value;
}

sub stringify {
    my $this = shift;

    if( $this->is_flag ) {
        my $arg = "FLAG[" . $this->name . "]";

        $arg .= "T<" . $this->token . ">" if $this->has_token and $ENV{CLISH_TOKEN_DEBUG};
        $arg .= "<V>" if $this->flag_present;

        return $arg;
    }

    my $arg = "ARG[" . $this->name . "]";
    $arg .= "T<" . $this->token . ">" if $this->has_token and $ENV{CLISH_TOKEN_DEBUG};
    $arg .= "V<" . $this->value . ">" if $this->has_value;

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

    if( defined $val ) {
        $obj->set_value( $val );

    } else {
        $obj->no_value;
    }

    return $obj;
}

sub copy_with_token {
    my $this = shift;
    my $obj  = bless { %$this }, ref $this;
    my $tok  = shift;

    if( defined $tok ) {
        $obj->set_token( $tok );

    } else {
        $obj->no_token;
    }

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
        die "$this incomplete argument specification (no validators)" if @$validators == 0;
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
