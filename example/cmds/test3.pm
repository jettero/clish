
package example::cmds::test3;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use common::sense;

command( name => 'test3',
    help => "just a silly parser test command",
    arguments => [
        optional_argument( msg => 'poo', help => "echo this text (only phrases beginning with \"poo\" are valid)", tag_optional => 1 )
    ],
);

sub exec {
    my $this = shift;
    my %opts = @_;

    say exists $opts{msg} ? $opts{msg} : "$this";
}

sub poo {
    my $this = shift;
    my $that = shift;

    return $that =~ m/^poo/;
}

__PACKAGE__->meta->make_immutable;

1;
