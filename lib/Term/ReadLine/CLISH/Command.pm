package Term::ReadLine::CLISH::Command;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use common::sense;
use Carp;
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

    # XXX: this should be an after() modifier on the reader only, but I can't get it to work

    return [ map { $_->with_context($this) } @{$this->_arguments} ];
};

# boring built-in validators

sub validate_nonempty_string { $_[1] || undef }
sub validate_nonzero_number  { 0 + $_[1] || undef }
sub validate_positive_number { my $x = 0 + $_[1]; $x >= 0 ? $x : undef }

1;
