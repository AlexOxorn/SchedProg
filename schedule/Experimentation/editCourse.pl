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

my $frame1 = $edit_dialog->Frame( -height => 200, )->pack( -fill => 'x' );
my $frame2  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
my $frame2B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
my $frame2C = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
my $frame3  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
my $frame3A = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
my $frame3B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
my $frame4  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
my $frame4A = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
my $frame4B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );

my $secDrop;
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
$frame1->LabEntry(
	-textvariable => \$cNum,
	-width        => 20,
	-label        => 'Course Number',
	-labelPack    => [ -side => 'left' ]
)->pack;

$frame1->LabEntry(
	-textvariable => \$desc,
	-width        => 20,
	-label        => 'Course Name',
	-labelPack    => [ -side => 'left' ]
)->pack;

#-----------------------------------------
# Section Add/Remove/Edit
#-----------------------------------------
$secDrop = $frame2->JBrowseEntry(
	-label    => 'Sections:',
	-variable => \$curSec,
	-state    => 'readonly',
	-choices  => \%sectionName,
	-width    => 12
)->pack( -side => 'left', -expand => 1, -fill => 'x' );

$secAdd = $frame2B->Button(
	-text    => "Add and Edit Section",
	-command => sub {$mw->bell},
	-width => $Bwidth,
)->pack( -side => 'right', -expand => 0 );

$secAdd2 = $frame2B->Button(
	-text    => "Add Section(s)",
	-command => sub {$mw->bell},
	-width => $Swidth
)->pack( -side => 'right', -expand => 0 );

$secRem = $frame2->Button(
	-text    => "Remove Section",
	-command => sub {$mw->bell;},
	-width => $Bwidth
)->pack( -side => 'right', -expand => 0 );
$secEdit = $frame2->Button(
	-text    => "Edit Section",
	-command => sub {$mw->bell;},
	-width => $Swidth
)->pack( -side => 'right', -expand => 0 );

$sectionMessage = $frame2B->Label( -text => "" )->pack( -fill => 'x' );

#--------------------------------------------------------
# Teacher Add/Remove
#--------------------------------------------------------
$teachDrop = $frame3->JBrowseEntry(
	-label    => 'Add Teacher:',
	-variable => \$curTeach,
	-state    => 'readonly',
	-choices  => \%teacherName,
	-width    => 12
)->pack( -side => 'left', -expand => 1, -fill => 'x' );

$teachAdd = $frame3->Button(
	-text    => "Add To All Sections",
	-command => sub {$mw->bell},
	-width => $Bwidth
)->pack( -side => 'left', -expand => 0 );

$teachDropO = $frame3A->JBrowseEntry(
	-label    => 'Remove Teacher:',
	-variable => \$curTeachO,
	-state    => 'readonly',
	-choices  => \%teacherNameO,
	-width    => 12
)->pack( -side => 'left', -expand => 1, -fill => 'x' );

$teachRem = $frame3A->Button(
	-text    => "Remove From All Sections",
	-command => sub {$mw->bell},
	-width => $Bwidth
)->pack( -side => 'left', -expand => 0 );

$teachMessage = $frame3B->Label( -text => "" )->pack( -fill => 'x' );

#--------------------------------------------------------
# Stream Add/Remove
#--------------------------------------------------------
$streamDrop = $frame4->JBrowseEntry(
	-label    => 'Streams:',
	-variable => \$curStream,
	-state    => 'readonly',
	-choices  => \%streamName,
	-width    => 12
)->pack( -side => 'left', -expand => 1, -fill => 'x' );

$steamAdd = $frame4->Button(
	-text    => "Set To All Sections",
	-command => sub {$mw->bell},
	-width => $Bwidth
)->pack( -side => 'left', -expand => 0 );

$streamDropO = $frame4A->JBrowseEntry(
	-label    => 'Remove Streams:',
	-variable => \$curStreamO,
	-state    => 'readonly',
	-choices  => \%streamNameO,
	-width    => 12
)->pack( -side => 'left', -expand => 1, -fill => 'x' );

$streamRem = $frame4A->Button(
	-text    => "Remove Stream",
	-command => sub {$mw->bell},
	-width => $Bwidth
)->pack( -side => 'left', -expand => 0 );

$streamMessage = $frame4B->Label( -text => "" )->pack( -fill => 'x' );

my $answer = $edit_dialog->Show();
$answer = "Close" unless $answer;

