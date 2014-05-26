
package example::cmds::test1;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use common::sense;

command(
    help => "just a silly parser test command",
    arguments => [
        optional_argument(
            msg => "validate_nonempty_string",
            help => "echo this text",
            default => "executing " . __PACKAGE__,
            tag_optional => 1 ),
    ],
);

sub exec {
    my $this = shift;
    my $opts = shift;

    $opts->{msg} || $opts->{_}{msg}->default;

    say exists $opts->{msg} ? $opts->{msg} : "$this";
}

__PACKAGE__->meta->make_immutable;

1;
