package Term::ReadLine::CLISH::Library::Commands::Copy;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs :tool);
use File::Slurp qw(slurp write_file);
use Cwd;
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
        optional_argument( file => "valid_file_basename",
            help => "copy to (or from) a named file",
            tag_optional => 1,
            takes_files => 1,
            before_completion => sub { $::OLD_CURDIR = getcwd; chdir $::THIS_CLISH->locate_config_file },
             after_completion => sub { chdir $::OLD_CURDIR },
        ),
    ],
);

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;
    my $args = shift;
    my ($src, $dst) = @$args;

    my $config_to_copy;

    # SRC
    if( $src->is_flag and $src->name eq "running-config" ) {
        info "building configuration";
        $config_to_copy = $::THIS_CLISH->configuration->stringify_config;

    } elsif( $src->is_flag and $src->name eq "startup-config" ) {
        my $fname = $::THIS_CLISH->locate_config_file(
            $::THIS_CLISH->configuration->startup_config_filename
        );
        $config_to_copy = my_read( $fname ) or return;

    } else {
        my $fname = $::THIS_CLISH->locate_config_file( $src->value );
        $config_to_copy = my_read( $fname ) or return;
    }

    # DST
    if( $dst->is_flag and $dst->name eq "running-config" ) {
        info "merging into running-config";
        $::THIS_CLISH->configuration->execute_configuration( $config_to_copy );

    } elsif( $dst->is_flag and $dst->name eq "startup-config" ) {
        info "writing to startup-config";
        my $fname = $::THIS_CLISH->locate_config_file(
            $::THIS_CLISH->configuration->startup_config_filename
        );
        my_write( $fname => $config_to_copy ) or return;

    } else {
        my $sfname = $dst->value;
        info "copying to $sfname";
        my $fname = $::THIS_CLISH->locate_config_file( $sfname );
        my_write( $fname => $config_to_copy ) or return;
    }
}

sub my_write {
    my $file = shift;
    my $contents = shift;

    unless( eval { write_file( $file => $contents ); 1 } ) {
        error "problem writing $file", scrub_last_error();
        return 0;
    }

    return 1;
}

sub my_read {
    my $file = shift;
    my $contents = eval { slurp($file) };

    if( not defined $contents ) {
        error "problem reading $file", scrub_last_error();
    }

    return $contents;
}

sub valid_file_basename {
    my $this = shift;
    my $arg  = shift;

    return if $arg =~ m{/};
    return $arg;
}

1;
