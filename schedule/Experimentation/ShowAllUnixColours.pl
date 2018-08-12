#!/usr/bin/perl
use strict;
use warnings;
use Tk;
use FindBin;
use lib "$FindBin::Bin/..";
use PerlLib::Colour;
my $mw = MainWindow->new;
my $f = $mw->Scrolled("Frame")->pack(-expand=>1,-fill=>'both');
my $colours = Colour->colours_hash();
foreach my $c (keys %$colours) {
    my $bg = Colour->new($c);
    my $fg = "white";
    $fg = "black" if $bg->isLight;
    $f->Button(-text=>$c,-background=>$bg->string,-foreground=>$fg)->pack;
}
MainLoop;