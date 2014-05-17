
package Term::ReadLine::CLISH::Parser;

use Moose;
use namespace::autoclean;
use Moose::Util::TypeConstraints;
use Term::ReadLine::CLISH::Error;
use Term::ReadLine::CLISH::Warning;
use common::sense;

subtype 'pathArray', as 'ArrayRef[Str]';
coerce 'pathArray', from 'Str', via { [ split m/[:; ]+/ ] };

subtype 'cmd', as 'Term::ReadLine::CLISH::Command';
subtype 'cmdArray', as 'ArrayRef[cmd]';
coerce 'cmdArray', from 'cmd', via { [ $_ ] };

has qw(path is rw isa pathArray coerce 1);
has qw(prefix is rw isa Str);
has qw(cmds is rw isa cmdArray coerce 1);

__PACKAGE__->meta->make_immutable;

sub BUILD {
    my $this = shift;

    $this->reload_commands;
}

sub reload_commands {
    my $this = shift;
    my $PATH = $this->path;
    my $prefix = $this->prefix;
       $prefix =~ s{::}{/}g;

    my @cmds;

    for my $path (grep {m{\Q$prefix}} @$PATH) {
        for my $f (glob("$path/*.pm")) {
            if( my ($ppackage) = $f =~ m{(\Q$prefix\E.*?)\.pm} ) {
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
