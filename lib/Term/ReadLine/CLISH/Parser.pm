
package Term::ReadLine::CLISH::Parser;

use Moose;
use namespace::autoclean;
use Moose::Util::TypeConstraints;
use Term::ReadLine::CLISH::Error;
use common::sense;

subtype 'pathArray', as 'ArrayRef[Str]';
coerce 'pathArray', from 'Str', via { [ split m/[:; ]+/ ] };

subtype 'prefixArray', as 'ArrayRef[Str]';
coerce 'prefixArray', from 'Str', via { [ $_ ] };

subtype 'cmd', as 'Term::ReadLine::CLISH::Command';
subtype 'cmdArray', as 'ArrayRef[cmd]';
coerce 'cmdArray', from 'cmd', via { [ $_ ] };

has qw(path is rw isa pathArray coerce 1);
has qw(prefix is rw isa prefixArray);
has qw(cmds is rw isa cmdArray coerce 1);

__PACKAGE__->meta->make_immutable;

sub BUILD {
    my $this = shift;

    $this->reload_commands;
}

sub prefix_regex {
    my $this = shift;
    my @prefixes = map {s{::}{/}g} @{ $this->prefix };
    local $" = "|";
    my $RE = qr{(?:@prefixes)};
    return $RE;
}

sub reload_commands {
    my $this = shift;
    my $PATH = $this->path;
    my $prreg = $this->prefix_regex;

    my @cmds;

    for my $path (grep {$_ =~ $prreg} @$PATH) {
        for my $f (glob("$path/*.pm")) {
            if( my ($ppackage) = $f =~ m{($:rreg.*?)\.pm} ) {
                my $package = $ppackage; $package =~ s{/}{::}g;
                my $newcall = "use $package; $package" . "->new";
                my $obj     = eval $newcall;

                if( $obj ) {
                    push @cmds, $obj;

                } else {
                    Term::ReadLine::CLISH::Error->new->spew("while trying to load '$ppackage as $package'");
                }
            }
        }
    }

    $this->cmds(\@cmds);
}

1;
