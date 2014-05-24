package Term::ReadLine::CLISH::Command;

use Moose;
use namespace::autoclean;
use common::sense;

# NOTE: this is just a stub.  use Term::ReadLine::CLISH::Command::Moose instead

has qw(unusual_invocation is ro isa Bool default) => 0;

__PACKAGE__->meta->make_immutable;

sub BUILD {
    my $this = shift;
    my $ref = ref $this;

    eval qq{
        package $ref;
        use overload '""' => \\&Term::ReadLine::CLISH::Command::stringify, fallback => 1;
    };
}

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
