package Term::ReadLine::CLISH::Library::Commands::Copy;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use common::sense;

command(
    help => "copy <src> <dst> — copy files or configurations",
    argument_options => {
        min_arguments => 2,
        max_arguments => 2,
        requre_unique => 1,
    },
    arguments => [
        optional_argument( 'startup-config' => undef, is_flag=>1, help => "copy to (or from) the startup configuration" ),
        optional_argument( 'running-config' => undef, is_flag=>1, help => "copy to (or from) the running configuration" ),
        optional_argument( file => "valid_file_basename", help => "copy to (or from) a named file", tag_optional => 1 ),
    ],
);

has qw(startup_config_filename is rw isa Str default startup-config);

__PACKAGE__->meta->make_immutable;

use Data::Dump::Filtered qw(add_dump_filter); use Data::Dump qw(dump);
add_dump_filter(sub{ my ($ctx, $obj) = @_; return { dump => "q«$obj»" } if $ctx->is_blessed; });

sub exec {
    my $this = shift;
    my $args = shift;

    use Data::Dump qw(dump);
    todo "do something with the args", dump($args);
}

sub valid_file_basename {
    my $this = shift;
    my $arg  = shift;

    return if $arg =~ m{/};
    return 1;
}

1;
