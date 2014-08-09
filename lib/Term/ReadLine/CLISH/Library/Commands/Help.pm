package Term::ReadLine::CLISH::Library::Commands::Help;

=encoding UTF-8

=head1 INVOCATION

    help [pod] [<command-name>]

=head1 OPTIONS

=over

=item C<< pod <command-name> >>

Display the help pages for this command.  C<pod> defaults to this page if the
desired page is not specified.

=back

=head1 NOTATIONS

=over

=item C<< literal >>

This C<literal> is meant to be typed as-is.

=item C<< [literal] >>

This C<literal> is (like above) mean to be typed as-is, but may be skipped

=item C<< <something> >>

This C<something> is a user supplied string or argument.  Arguments

=item C<< [<something>] >>

This C<something> is a user supplied string that may be skipped, perhaps because ∃ a default.

=back

=head1 ARGUMENTS

Arguments may come in tag-pairs, (e.g., C<< tagname <user-string> >>.  Many
arguments may be specified without a tag, in which case, they are consumed in
the order they are specified in the command definition.

=cut

use Term::ReadLine::CLISH::Command::Moose;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use IPC::System::Simple qw(systemx);
use namespace::autoclean;
use common::sense;

command(
    help => "launch the perldoc (aka pod) for a command",
    arguments => [
        optional_argument(
            pod => 'validate_pod', tag_optional => 1, default => __PACKAGE__,
            help => "the command to peruse (default: this command)" )
    ],
);

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;
    my $opts = shift;

    my $pager = eval { $::THIS_CLISH->configuration->setting("pager") || [qw(less -nXRESz-4)] };
       $page ||= [ 'more' ];

    local $ENV{PAGER} = "@$pager";

    my $pod = $opts->{pod}->value_or_default;
    systemx( perldoc => $pod );

    return;
}

sub validate_pod {
    my $this = shift;
    my $that = shift;
    my %opt  = @_;

    return Term::ReadLine::CLISH::Command->validate_nonempty_string($that, %opt)
        if $opt{heuristic_validation};

    return ref $this if lc($that) eq "clish";
    return ref $_ if $_ = $::THIS_CLISH_PARSER->find_command_by_name($that);

    $@ = "couldn't find a help page for '$that'";
    return;
}

1;
