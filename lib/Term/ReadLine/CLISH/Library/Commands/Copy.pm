package Term::ReadLine::CLISH::Library::Commands::Copy;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use File::Slurp qw(slurp);
use common::sense;

command(
    help => "copy <src> <dst> — copy files or configurations",
    argument_options => {
        min_arguments => 2,
        max_arguments => 2,
        positional => 1,
    },
    arguments => [
        optional_argument( 'startup-config' => undef, is_flag=>1, help => "copy to (or from) the startup configuration" ),
        optional_argument( 'running-config' => undef, is_flag=>1, help => "copy to (or from) the running configuration" ),
        optional_argument( file => "valid_file_basename", help => "copy to (or from) a named file", tag_optional => 1, takes_files => 1 ),
    ],
);

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;
    my $args = shift;
    my ($src, $dst) = @$args;

    my $config_to_copy;
    if( $src->is_flag and $src->name eq "running-config" ) {
        $config_to_copy = $::THIS_CLISH->configuration->stringify_config;

    } elsif( $src->is_flag and $src->name eq "startup-config" ) {
        my $fname = $::THIS_CLISH->locate_config_file(
            $::THIS_CLISH->configuration->startup_config_filename
        );
        $config_to_copy = slurp( $fname );

    } else {
        my $fname = $::THIS_CLISH->locate_config_file( $src->value );
        $config_to_copy = slurp( $fname );
    }

    todo Data::Dump::dump( $config_to_copy );
}

sub valid_file_basename {
    my $this = shift;
    my $arg  = shift;

    return if $arg =~ m{/};
    return 1;
}

1;
