
package example::cmds::test4;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use common::sense;

command(
    help => "just a silly parser test command",
    arguments => [
        optional_argument( msg => 'fupa', help => "echo this text (only phrases beginning with \"fupa\" are valid)", tag_optional => 1 )
    ],
);

sub exec {
    my $this = shift;
    my $opts = shift;

    say exists $opts->{msg} ? $opts->{msg} : "$this";
}

sub fupa {
    my $this = shift;
    my $that = shift;

    return $that =~ m/^fupa/ && uc $that;;
}

__PACKAGE__->meta->make_immutable;

1;
