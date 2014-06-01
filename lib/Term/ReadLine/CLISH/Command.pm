package Term::ReadLine::CLISH::Command;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use Carp;
use Term::ReadLine::CLISH::MessageSystem;
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

sub arguments {
    my $this = shift;
    croak "you can't change the arguments this way" if @_;

    # NOTE: this should be a Moose after() method-modifier on the reader only, but I can't get it to work
    return [ map { $_->copy_with_context($this) } @{$this->_arguments} ];
};

sub validate {
    my $this = shift;

    my $error_count = 0;
    for( @{ $this->arguments } ) {
        if( $_->has_token ) {
            error "with $_" unless $_->validate(final_validation=>1);
            $error_count ++;

        } elsif( $_->required ) {
            error "with $_", "required argument omitted";
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
