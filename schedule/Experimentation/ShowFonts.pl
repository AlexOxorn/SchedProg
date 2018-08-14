#!/usr/bin/perl
use strict;
use warnings;
use Tk;
use Tk::Pane;
my $mw = MainWindow->new;
my $f = $mw->Scrolled('Frame')->pack(-expand=>1,-fill=>'both');
foreach my $font (sort $mw->fontFamilies) {
    my $x = $mw->fontCreate(-family=>"arial",-size=>16);
    
    eval {next if $font=~/goha/;print "$font\n";$x = $mw->fontCreate(-family=>"$font",-size=>16);};
    $f->Label(-text=>$font, -font=>$x)->pack;
    eval {next if $font=~/goha/;print "$font\n";$x = $mw->fontCreate(-weight=>'bold',-family=>"$font",-size=>16);};
    $f->Label(-text=>$font, -font=>$x)->pack;
}
MainLoop;