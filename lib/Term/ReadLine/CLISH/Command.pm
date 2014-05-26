package Term::ReadLine::CLISH::Command;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use common::sense;
use overload '""' => \&stringify, fallback => 1;

subtype 'Option', as 'Term::ReadLine::CLISH::Command::Option';

# NOTE: use Term::ReadLine::CLISH::Command::Moose  for the command()  sugar

has qw'name is ro isa Str default' => "unfinished command";
has qw'help is ro isa Str default' => "unfinished command";
has qw'arguments is ro isa ArrayRef[Option] default' => sub {[]};

__PACKAGE__->meta->make_immutable;

sub stringify {
    my $this = shift;

    return "CMD[" . $this->name . "]";
}

sub _start_parse {
    my $this = shift;
    my $arg  = shift;

    $this->_parse_info([]);

    return $this->name =~ m/^\Q$arg/;
}

sub _continue_parse {
    my $this = shift;

    warn "XXX: check to see if $this can accept <<< @_ >>> as args";

    return 1;
}

1;
