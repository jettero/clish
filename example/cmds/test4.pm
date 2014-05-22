
package example::cmds::test4;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use common::sense;

command( name => 'test4',
    help => "just a silly parser test command",
    arguments => [
        optional_argument( msg => 'fupa', => "echo this text (only phrases beginning with \"fupa\" are valid)", tag_optional => 1 )
    ],
);

sub exec {
    my $this = shift;
    my %opts = @_;

    say exists $opts{msg} ? $opts{msg} : "$this";
}

sub fupa {
    my $this = shift;
    my $that = shift;

    return $that =~ m/^fupa/;
}

__PACKAGE__->meta->make_immutable;

1;
