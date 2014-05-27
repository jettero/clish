#!/usr/bin/perl -Ilib

use common::sense;
use Term::ReadLine::CLISH;

Term::ReadLine::CLISH->new(name=>"Example Shell", version=>"0.1", prompt=>"exsh> ")
    -> add_namespace("example::cmds")
    -> run;
