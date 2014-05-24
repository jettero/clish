
package Term::ReadLine::CLISH::Parser;

use Moose;
use namespace::autoclean;
use Moose::Util::TypeConstraints;
use Term::ReadLine::CLISH::MessageSystem;
use Parse::RecDescent;
use File::Find::Object;
use common::sense;

subtype 'pathArray', as 'ArrayRef[Str]';
coerce 'pathArray', from 'Str', via { [ split m/[:; ]+/ ] };

subtype 'prefixArray', as 'ArrayRef[Str]';
coerce 'prefixArray', from 'Str', via { [ $_ ] };

subtype 'cmd', as 'Term::ReadLine::CLISH::Command';
subtype 'cmdArray', as 'ArrayRef[cmd]';
coerce 'cmdArray', from 'cmd', via { [ $_ ] };

has qw(path is rw isa pathArray coerce 1);
has qw(prefix is rw isa prefixArray);
has qw(cmds is rw isa cmdArray coerce 1);
has qw(parser is rw isa Parse::RecDescent);

has qw(output_prefix is rw isa Str default) => "% ";

__PACKAGE__->meta->make_immutable;

sub parse {
    my $this = shift;
    my $line = shift;

    my $prefix = $this->output_prefix;
    my $parser = $this->parser;
    my $result = $parser->command($line);

    error "parse error [1]" unless $result;

    use Data::Dump qw(dump);
    debug "result: " . dump($result);

    return $result;
}

sub BUILD {
    my $this = shift;
       $this->reload_commands;
       $this->build_parser;
}

sub build_parser {
    my $this = shift;

    # NOTE: $::blah is $main::blah, RD uses it all over

    $::RD_HINT = 1; # let the parser generator give meaningful errors
    $::this = $this;

    my $parser = Parse::RecDescent->new(q
        tokens: token(s?) { $return = $item[1] } /$/

        token: word | string | /\s*/ <reject: $@ = "mysterious goo on line $thisline column $thiscolumn near, \"$text\"">

        word: /[\w\d_.-]+/ { $return = $item[1] }

        string: "'" /[^']*/ "'" { $return = $item[2] }
              | '"' /[^"]*/ '"' { $return = $item[2] }
    );

    my @names = $this->command_names;
    my %collision_strings;
    my %namel;

    for my $n (@names) {
        my ($r,@m);

        while( @m != 1 ) {
            $namel{$n} ++;
            $r = substr $n, 0, $namel{$n};
            @m = grep { m/^\Q$r/ } @names;
        }

        continue {
            $collision_strings{$r}{$n} = undef unless @m == 1;
        }

    }

    %::CMDS_BY_NAME = ();
    %::OPTIONS_VALIDATORS = ();

    for my $cmd (@{$this->cmds}) {
        my $cname = $cmd->name;
        die "$cmd\'s name has characters that simply won't work in a grammar" if $cname =~ m/[^\w\_\d]/;

        for my $arg (@{$cmd->arguments}) {
            my $aname = $arg->name;
            die "$cmd\'s option '$aname' name has characters that simply won't work in a grammar" if $aname =~ m/[^\w\_\d]/;

            my $type = $arg->required ? "argument" : "option";
            my $oreg = do { my @a = split "", $aname; "m/$a[0]" . join("?", @a[1 .. $#a]) . "?/" };
            my $tag  = $arg->tag_optional ? "( $oreg )(?)" : "$oreg";

            my $pname = join("_", $type, $cname, $aname );
            my $production = "$pname: $tag token <reject: !\$::OPTIONS_VALIDATORS{$pname}->(\$item[2])> { +{$aname => \$item[2]} }";

            $::OPTIONS_VALIDATORS{$pname} = sub {
                warn "XXX: $pname validator fired → ACCEPTING"
            };

            debug "adding argument/option production: $production";
            $parser->Extend($production);
        }

        local $" = "|";
        $::CMDS_BY_NAME{$cname} = $cmd;

        my @shorts = grep { not exists $collision_strings{$_} } map { substr $cname, 0, $_ } 1 .. length $cname;
        my $production = "command: /^(?:@shorts)\\b/ /\$/ { \$return = [\$::CMDS_BY_NAME{$cname}, []] }";

        debug "adding command production: $production";
        $parser->Extend($production);
    }

    ADD_COLLISION_PRODUCTIONS: {
        my @collision_strings = sort keys %collision_strings;
        local $" = "|";
        my $production = "command: /^(?:@collision_strings)\$/ "
           . '<reject: do { my @c = sort keys %{$::COLLISIONS{$item[1]}}; '
           . '$@ = "\"$item[1]\" could be any of: @c" }>';

        debug "adding production: $production";

        $parser->Extend($production);
        %::COLLISIONS = %collision_strings;
    }

    die "unable to parse command grammar in parser generator\n" unless $parser;
    # XXX: should have a better error handler later

    $this->parser($parser);
}

sub command_names {
    my $this = shift;
    my @cmd  = @{ $this->cmds };

    my %h;
    return sort map { $_->name } grep { !$h{$_}++ } @cmd;
}

sub prefix_regex {
    my $this = shift;
    my @prefixes = @{ $this->prefix };
    s{::}{/}g for @prefixes;
    local $" = "|";
    my $RE = qr{(?:@prefixes)};
    return $RE;
}

sub reload_commands {
    my $this = shift;
    my $PATH = $this->path;
    my $prreg = $this->prefix_regex;

    my @cmds;

    for my $path (@$PATH) {
        my $ffo = File::Find::Object->new({}, $path);

        debug "trying to load commands from $path using $prreg";

        while( my $f = $ffo->next ) {
            debug "    considering $f";

            if( -f $f and my ($ppackage) = $f =~ m{($prreg.*?)\.pm} ) {
                my $package = $ppackage; $package =~ s{/}{::}g;
                my $newcall = "use $package; $package" . "->new";
                my $obj     = eval $newcall;

                if( $obj ) {
                    if( $obj->isa("Term::ReadLine::CLISH::Command") ) {
                        debug "    loaded $ppackage as $package";
                        if( $obj->unusual_invocation ) {
                            debug "    [intended for unusual invocation, skipping command list]";

                        } else {
                            push @cmds, $obj;
                        }

                    } else {
                        debug "    loaded $ppackage as $package — but it didn't appear to be a Term::ReadLine::CLISH::Command";
                    }

                } else {
                    error "    while trying to load '$ppackage as $package'";
                }
            }
        }
    }

    my $c = @cmds;
    my $p = $c == 1 ? "" : "s";

    info "[loaded $c command$p from PATH]";

    $this->cmds(\@cmds);
}

1;
