#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use Carp;
use Tk;
use lib "$FindBin::Bin/..";
use Tk::DynamicTree;
use Tk::DragDrop;
use Tk::DropSite;
use Tk::ItemStyle;
use Tk::FindImages;
use PerlLib::Colours;
use Tk::FindImages;
use Tk::Dialog;
use Tk::Menu;
use Tk::LabEntry;
use Tk::Optionmenu;
use Tk::JBrowseEntry;
my $image_dir = Tk::FindImages::get_image_dir();



my $change = 0;

#-----------------------------
# Create Menu Values
#-----------------------------

my $cNum = 0;
my $desc = "TEST";

my $startNum  = $cNum;
my $startDesc = $desc;

my $curSec   = "";

my %sectionName;

my $curTeach = "";

my %teacherName;

my $curTeachO = "";
my %teacherNameO;

my $curStream = "";
my %streamName;

my $curStreamO = "";
my %streamNameO;

#---------------------------------------------------
# Creating Frames and defining widget variable names
#---------------------------------------------------

my $mw = MainWindow->new;

my $edit_dialog = $mw->DialogBox(
	-title   => "Edit Course",
	-buttons => [ 'Close', 'Delete' ]
);

#my $frame1 = $edit_dialog->Frame( -height => 200, )->pack( -fill => 'x' );
#my $frame2  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
#my $frame2B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
#my $frame2C = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
#my $frame3  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
#my $frame3A = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
#my $frame3B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
#my $frame4  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
#my $frame4A = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
#my $frame4B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );

my $secDrop;
my $secDropLabel;
my $secAdd;
my $secAdd2;
my $secRem;
my $secEdit;
my $teachDropO;
my $teachDrop;
my $teachAdd;
my $teachRem;
my $streamDropO;
my $streamDrop;
my $steamAdd;
my $streamRem;

my $sectionMessage;
my $teachMessage;
my $streamMessage;

my $Bwidth = 22;
my $Swidth = 12;

#-----------------------------------------
#Course number and name entry entry
#-----------------------------------------
my $w1 = $edit_dialog->LabEntry(
	-textvariable => \$cNum,
);

my $w1a = $edit_dialog->Label( -text => "Course Number" )->grid($w1,'-','-',-sticky=>"nsew");

my $w2 = $edit_dialog->LabEntry(
	-textvariable => \$desc,
);

my $w2a = $edit_dialog->Label( -text => "Course Name" )->grid($w2,'-','-',-sticky=>"nsew");



#-----------------------------------------
# Section Add/Remove/Edit
#-----------------------------------------
$secDrop = $edit_dialog->JBrowseEntry(
	-variable => \$curSec,
	-state    => 'readonly',
	-choices  => \%sectionName,
	-width    => 12
);

$secAdd = $edit_dialog->Button(
	-text    => "Add and Edit Section",
	-command => sub {$mw->bell},
	-width => $Bwidth,
);

$secAdd2 = $edit_dialog->Button(
	-text    => "Add Section(s)",
	-command => sub {$mw->bell},
	-width => $Swidth
);

$secDropLabel = $edit_dialog->Label( -text => "Sections:" )->grid($secDrop,$secAdd2,$secAdd, -sticky=>"nsew");

$secRem = $edit_dialog->Button(
	-text    => "Remove Section",
	-command => sub {$mw->bell;},
	-width => $Bwidth
);
$secEdit = $edit_dialog->Button(
	-text    => "Edit Section",
	-command => sub {$mw->bell;},
	-width => $Swidth
);

$sectionMessage = $edit_dialog->Label( -text => "" );

#--------------------------------------------------------
# Teacher Add/Remove
#--------------------------------------------------------
$teachDrop = $edit_dialog->JBrowseEntry(
	-label    => 'Add Teacher:',
	-variable => \$curTeach,
	-state    => 'readonly',
	-choices  => \%teacherName,
	-width    => 12
);

$teachAdd = $edit_dialog->Button(
	-text    => "Add To All Sections",
	-command => sub {$mw->bell},
	-width => $Bwidth
);

$teachDropO = $edit_dialog->JBrowseEntry(
	-label    => 'Remove Teacher:',
	-variable => \$curTeachO,
	-state    => 'readonly',
	-choices  => \%teacherNameO,
	-width    => 12
);

$teachRem = $edit_dialog->Button(
	-text    => "Remove From All Sections",
	-command => sub {$mw->bell},
	-width => $Bwidth
);

$teachMessage = $edit_dialog->Label( -text => "" );

#--------------------------------------------------------
# Stream Add/Remove
#--------------------------------------------------------
$streamDrop = $edit_dialog->JBrowseEntry(
	-label    => 'Streams:',
	-variable => \$curStream,
	-state    => 'readonly',
	-choices  => \%streamName,
	-width    => 12
);

$steamAdd = $edit_dialog->Button(
	-text    => "Set To All Sections",
	-command => sub {$mw->bell},
	-width => $Bwidth
);

$streamDropO = $edit_dialog->JBrowseEntry(
	-label    => 'Remove Streams:',
	-variable => \$curStreamO,
	-state    => 'readonly',
	-choices  => \%streamNameO,
	-width    => 12
);

$streamRem = $edit_dialog->Button(
	-text    => "Remove Stream",
	-command => sub {$mw->bell},
	-width => $Bwidth
);

$streamMessage = $edit_dialog->Label( -text => "" );

my $answer = $edit_dialog->Show();
$answer = "Close" unless $answer;

