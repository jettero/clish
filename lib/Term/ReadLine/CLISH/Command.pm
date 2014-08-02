package Term::ReadLine::CLISH::Command;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use Carp;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use common::sense;
use overload '""' => \&stringify, fallback => 1;

subtype 'Argument', as 'Term::ReadLine::CLISH::Command::Argument';

# NOTE: use Term::ReadLine::CLISH::Command::Moose  for the command()  sugar

has qw'name is ro isa Str default' => "unfinished command";
has qw'help is ro isa Str default' => "unfinished command";
has qw'arguments is ro isa ArrayRef[Argument] reader _arguments default' => sub {[]};

__PACKAGE__->meta->make_immutable;

sub stringify {
    my $this = shift;

    return "CMD[" . $this->name . "]";
}

sub stringify_as_command_line {
    my $this = shift;
    my $args = shift; # XXX: this quotifier isn't very robust
    my $line = join(" ", map {m/\s/ ? "\"$_\"" : $_} map {$_->is_flag
        ? ($_->flag_present ? $_->name              : ())
        : ($_->has_value    ? ($_->name, $_->value) : ())
        } values %$args);

    return $line;
}

sub arguments {
    my $this = shift;
    croak "you can't change the arguments this way" if @_;

    # NOTE: this should be a Moose after() method-modifier on the reader only, but I can't get it to work
    return [ map { $_->copy_with_context($this) } @{$this->_arguments} ];
};

sub validate {
    my $this = shift;
    my $args = shift; # there isn't a great place to store the *POPULATED* args
                      # in the command object... should there be?

    debug "$this final validation" if $ENV{CLISH_DEBUG};

    my $error_count = 0;
    for( values %$args ) {
        if( $_->has_value ) {
            debug "$_ already has a value (" . $_->value . "), no reason to validate" if $ENV{CLISH_DEBUG};
            next;

        } elsif( $_->has_token ) {
            debug "$_ (has_token: " . $_->token . "), issuing final validation" if $ENV{CLISH_DEBUG};
            unless( $_->validate_copy_with_value_to_hashref($args) ) {
                # validate prints its own errors, just count up
                $error_count ++;
            }

        } elsif( $_->required ) {
            debug "$_ seems to be missing, not validating, just complaining" if $ENV{CLISH_DEBUG};
            error "$error_count with $_", "required argument omitted";
            $error_count ++;
        }
    }

    return !$error_count;
}

# boring built-in argument validators

sub validate_nonempty_string  { $_[1] || undef }
sub validate_positive_nonzero { 0 + $_[1] || undef }
sub validate_positive         { my $x = 0 + $_[1]; $x >= 0 ? $x : undef }
sub validate_integer          { $_[1] =~ m/[\D-]/ ? undef : $_[1] }

1;
