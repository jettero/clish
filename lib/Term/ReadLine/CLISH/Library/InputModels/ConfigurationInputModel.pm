package Term::ReadLine::CLISH::Library::InputModels::ConfigurationInputModel;

use Moose;
use common::sense;

extends 'Term::ReadLine::CLISH::InputModel';

__PACKAGE__->meta->make_immutable;

sub post_exec {
    my $this = shift;
    my ($cmd, $args) = @_;

    wtf "[post_exec] $cmd @{[map{($_=>$args->{$_})} keys %$args]}";

    return unless $cmd->can("configuration_slot");

    my $slot = $cmd->configuartion_slot;

    wtf "[post_exec] $cmd slot=$slot";

    $::CLISH->configuration->set($slot, $cmd, $args);
}

1;