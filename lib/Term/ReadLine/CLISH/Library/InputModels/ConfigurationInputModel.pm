package Term::ReadLine::CLISH::Library::InputModels::ConfigurationInputModel;

use Moose;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use common::sense;

extends 'Term::ReadLine::CLISH::InputModel';

__PACKAGE__->meta->make_immutable;

sub post_exec {
    my $this = shift;
    my ($cmd, $args) = @_;

    wtf "[post_exec] $cmd";

    return unless my $slot = $cmd->configuration_slot;
    my $line = $cmd->stringify_as_command_line($args);

    wtf "[post_exec] $cmd slot=$slot line=$line";

    $::THIS_CLISH->configuration->set($slot, $line);
}

1;
