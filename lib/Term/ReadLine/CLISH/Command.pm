package Term::ReadLine::CLISH::Command;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use common::sense;
use overload '""' => \&stringify, fallback => 1;

subtype 'Argument', as 'Term::ReadLine::CLISH::Command::Argument';

# NOTE: use Term::ReadLine::CLISH::Command::Moose  for the command()  sugar

has qw'name is ro isa Str default' => "unfinished command";
has qw'help is ro isa Str default' => "unfinished command";
has qw'arguments is ro isa ArrayRef[Argument] default' => sub {[]};

after arguments => sub {
    my $this = shift;

    return [ map { my $o = $_->clone_object; $o->context($this); $o } @{$this->{arguments}} ];
};

__PACKAGE__->meta->make_immutable;

sub stringify {
    my $this = shift;

    return "CMD[" . $this->name . "]";
}

1;
