#!/usr/bin/perl -w

use strict ;

my @keys ;

while (<>) {
  @keys = split(/<Key>/) ;
  shift @keys ;
  for (@keys) {
    $_ =~ /([^\<]+)/ ;
    print "$1\n"
  }
}