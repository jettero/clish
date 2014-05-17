# vi:set syntax=perl:

use ExtUtils::MakeMaker;

my $value = prompt("include modules required for the examples? [N/y] ");

WriteMakefile(
    NAME         => 'Term::ReadLine::CLISH',
    DISTNAME     => 'term-readline-clish',
    VERSION_FROM => 'lib/Term/ReadLine/CLISH.pm',

    PREREQ_PM => {
        map {($_=>0)} qw(
            common::sense
            Moose
            Term::Shelly
            IPC::System::Simple
            Net::IP
        )
    },

    ($ExtUtils::MakeMaker::VERSION ge '6.48'?
        (MIN_PERL_VERSION => 5.006001,
            META_MERGE => {
                keywords => [qw(ios cli shell)],
                resources=> {
                    repository => 'http://github.com/jettero/term-readline-clish',
                },
            },

        LICENSE	=> 'gpl3-artistic',
    ) : ()),
);
