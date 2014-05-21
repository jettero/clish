package Term::ReadLine::CLISH::Command;

use Moose;
use namespace::autoclean;
use common::sense;

# NOTE: this is just a stub.  use Term::ReadLine::CLISH::Command::Moose instead

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

1;
