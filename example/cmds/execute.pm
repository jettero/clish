package example::cmds::execute;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;

use Net::DNS;
use Net::IP;
use IPC::System::Simple 'systemx';
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use common::sense;

command(
    help => "execute some code via the running perl or a subshell",
    arguments => [
        optional_argument( shell => undef, is_flag=>1, help => "fork a shell (via the environment SHELL)" ),
        required_argument( code => 'validate_nonempty_string', tag_optional=>1, help => "the code to execute" )
    ],

    alias => 'x',
);

has qw'resolver is rw isa Net::DNS::Resolver';

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;
    my $opts = shift;

    if( $opts->{shell}->flag_present ) {
        my $shell = $ENV{SHELL} || "/bin/sh";
        if( my $retval = system( $shell => -c => $opts->{code}->value ) ) {
            if ($? == -1) {
                error "failed to execute", "$!";

            } elsif ($? & 127) {
                warning "shell died", sprintf("with signal %d%s",
                    ($? & 127),
                    ($? & 128) ? ' (dropped core)' : ''
                );

            } else {
                warning "non-zero shell exit", sprintf("chiled issued exit(%d)", $? >> 8);
            }
        }
        return;
    }

    my $code = $opts->{code}->value;
    {
        my $ref = ref $::THIS_CLISH;
        my $val = eval "package $ref; no strict; $code";

        use Data::Dump qw(dump);
        info "returned: " . dump($val) if defined $val;
    }
    error "while executing your code=\"$code\"" if $@;
    return;
}

1;
