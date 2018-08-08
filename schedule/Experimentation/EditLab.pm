#!/usr/bin/perl
use strict;
use warnings;

package EditLabs;
use FindBin;
use Carp;
use Tk;
use lib "$FindBin::Bin/..";
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



# =================================================================
# Class/Global Variables
# =================================================================
our $Max_id = 0;
my $Drag_source;
my $Schedule;
my $GuiSchedule;
my $Trash1_photo;
my $Trash2_photo;
my $Dragged_from;
my $Dirty_ptr;
my $Fonts;
my $Colours;
my %Styles;

my $frame;


# ===================================================================
# new
# ===================================================================
sub new {
	my $class = shift;
	$frame = shift;
	$Schedule  = shift;
	$Dirty_ptr = shift;
	$Colours   = shift;
	$Fonts     = shift;
	my $image_dir = shift;
	$GuiSchedule = shift;
	
	
	
}


sub junk{
	
	
	
}
	
	
	




1;