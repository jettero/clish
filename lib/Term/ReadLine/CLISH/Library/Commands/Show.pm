package Term::ReadLine::CLISH::Library::Commands::Show;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use File::Slurp qw(slurp);
use common::sense;

command(
    help => "show shell meta information",
    argument_options => {
        positional => 1,
    },
    arguments => [
        optional_argument( 'startup-config' => undef, is_flag=>1, help => "show the startup configuration", valid_after=>[] ),
        optional_argument( 'running-config' => undef, is_flag=>1, help => "show the running configuration", valid_after=>[] ),
    ],

    uses_pager => 1,
);

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;
    my $args = shift;
    my $out  = shift; # the pager stream

    if( $args->[0]->is_flag ) {
        given( $args->[0]->name ) {
            when( 'running-config' ) {
                print $out $::THIS_CLISH->configuration->stringify_configuration;
            }

            when( 'startup-config' ) {
                my $fname = $::THIS_CLISH->locate_config_file(
                    $::THIS_CLISH->configuration->startup_config_filename
                );

                if( my $config = eval {slurp( $fname )} ) {
                    print $out $config;
                }
            }
        }
    }
}
