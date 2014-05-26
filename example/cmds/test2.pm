
package example::cmds::test2;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use common::sense;

command(
    help => "just a silly parser test command",
    arguments => [
        optional_argument( msg => undef, help => "echo this text (default is some test text)", tag_optional => 1 ),
    ],
);

sub exec {
    my $this = shift;
    my $opts = shift;

    say exists $opts->{msg} ? $opts->{msg} : "$this";
}

__PACKAGE__->meta->make_immutable;

1;
