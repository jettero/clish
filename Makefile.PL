# vi:set syntax=perl:

use ExtUtils::MakeMaker;

my $value = exists $ENV{REQMOD_YES} ? $ENV{REQMOD_YES}
          : prompt("include modules required for the examples? [N/y] ");

WriteMakefile(

    NAME         => 'Term::ReadLine::CLISH',
    DISTNAME     => 'term-readline-clish',
    VERSION_FROM => 'lib/Term/ReadLine/CLISH.pm',

    PREREQ_PM => {

        map {($_=>0)} qw( 
            common::sense
            Data::Dump
            File::Find::Object
            File::HomeDir
            File::Slurp
            File::Spec
            IPC::System::Simple
            Moose
            namespace::autoclean
            namespace::sweep
            Parse::RecDescent
            Term::ANSIColorx::ColorNicknames
            Term::ReadLine
            Text::Table
            Tie::YAML
        )

    },

    ($ExtUtils::MakeMaker::VERSION ge '6.48'?

        (MIN_PERL_VERSION => 5.010000,
            META_MERGE => {
                keywords => [qw(ios cli shell)],
                resources=> {
                    repository => 'http://github.com/jettero/clish',
                },
            },

        LICENSE	=> 'gpl3-artistic',

    ) : ()),

);
