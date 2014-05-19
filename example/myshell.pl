#!/usr/bin/perl -Ilib

use common::sense;
use Term::ReadLine::CLISH;

Term::ReadLine::CLISH->new
    -> add_namespace("example::cmds")
    -> run;
