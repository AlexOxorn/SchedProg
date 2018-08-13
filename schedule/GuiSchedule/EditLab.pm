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
use Data::Dumper;
my $image_dir = Tk::FindImages::get_image_dir();

# =================================================================
# Class/Global Variables
# =================================================================
our $Max_id = 0;
my $Schedule;
my $GuiSchedule;
my $Trash1_photo;
my $Trash2_photo;
my %Styles;

my $frame;
my $day;
my $start;
my $duration;
my $lab;

my $course;
my $section;
my $block;
my $teacher;

my %dayName = (
	1 => "Monday",
	2 => "Tuesday",
	3 => "Wednesday",
	4 => "Thursday",
	5 => "Friday"
);

# ===================================================================
# new
# ===================================================================
sub new {
	my $class = shift;
	$frame    = shift;
	$Schedule = shift;

	#$GuiSchedule = shift;

	$day      = shift;
	$start    = shift;
	$duration = shift;

	$lab = shift;

	return OpenDialog();
}

sub OpenDialog {
	if ($Schedule) {

		#------------------------------------
		# SET UP TEACHER DATA
		#------------------------------------
		my @teachers = $Schedule->teachers->list;
		my $curTeach = "";
		my $newFName = "";
		my $newLName = "";

		my %teacherName;
		foreach my $i (@teachers) {
			$teacherName{ $i->id } = $i->firstname . " " . $i->lastname;
		}

		#------------------------------------
		# SET UP COURSE DATA
		#------------------------------------

		my @courses   = $Schedule->courses->list;
		my $curCourse = "";

		my %courseName;
		foreach my $i (@courses) {
			$courseName{ $i->id } = $i->print_description2;
		}

		#------------------------------------
		# SET UP SECTION DATA
		#------------------------------------

		my @sections;
		my $curSection = "";
		my $newSection = "";

		my %sectionName;

		#------------------------------------
		# SET UP BLOCK DATA
		#------------------------------------

		my @blocks   = $Schedule;
		my $curBlock = "";
		my $newBlock = "";

		my %blockName;

		#------------------------------------
		# Create Dialog Box
		#------------------------------------

		my $db = $frame->DialogBox(
			-title   => "Add Block to Resource",
			-buttons => [ "OK", "Cancel" ]
		);
		
		my $OKAY = $db->Subwidget("B_OK");
		$OKAY->configure(-state=>'disabled');

		my $fonts   = $Scheduler::Fonts;
		my $bigFont = $fonts->{big};

		# -----------------------------------
		# Create Main Labels
		# -----------------------------------

		my $MenuLabel = $db->Label(
			-text => $dayName{$day} . " at "
			  . _hoursToString($start) . " for "
			  . $duration
			  . "hour(s)",
			-font => $bigFont
		);

		my $CourseLabel  = $db->Label( -text => "Course:" );
		my $TeacherLabel = $db->Label( -text => "Teacher:" );
		my $SectionLabel = $db->Label( -text => "Section:" );
		my $BlockLabel   = $db->Label( -text => "Block:" );

		# -----------------------------------------------
		# Defining widget variable names
		# -----------------------------------------------

		my $CourseJBE;
		my $SectionJBE;
		my $TeacherJBE;
		my $BlockJBE;

		my $SectionEnt;
		my $TeacherFName;
		my $TeacherLName;

		my $SectionNew;
		my $TeacherNew;
		my $BlockNew;

		#----------------------------------------
		# Drop Down Lists widgets
		#----------------------------------------

		$CourseJBE = $db->JBrowseEntry(
			-variable  => \$curCourse,
			-state     => 'readonly',
			-choices   => \%courseName,
			-width     => 12,
			-browsecmd => sub {
				my %rHash = reverse %courseName;
				my $id    = $rHash{$curCourse};
				$course = $Schedule->courses->get($id);
				updateSectionList(
					\$SectionJBE, \$BlockJBE,   $course, \%sectionName,
					\%blockName,  \$curSection, \$curBlock, \$OKAY
				);
			}
		);
		my $courseDropEntry = $CourseJBE->Subwidget("entry");
		$courseDropEntry->configure( -disabledbackground => "white" );
		$courseDropEntry->configure( -disabledforeground => "black" );

		$SectionJBE = $db->JBrowseEntry(
			-variable  => \$curSection,
			-state     => 'readonly',
			-browsecmd => sub {
				my %rHash = reverse %sectionName;
				my $id    = $rHash{$curSection};
				$section = $course->get_section_by_id($id);
				print "Section ID <$id>\n";
				updateBlockList( \$BlockJBE, $section, \%blockName,
					\$curBlock , \$OKAY);
			}
		);
		my $secDropEntry = $SectionJBE->Subwidget("entry");
		$secDropEntry->configure( -disabledbackground => "white" );
		$secDropEntry->configure( -disabledforeground => "black" );

		$TeacherJBE = $db->JBrowseEntry(
			-variable  => \$curTeach,
			-state     => 'readonly',
			-choices   => \%teacherName,
			-browsecmd => sub {
				my %rHash = reverse %teacherName;
				my $id    = $rHash{$curTeach};
				$teacher = $Schedule->teachers->get($id);
			}
		);
		my $teacherDropEntry = $TeacherJBE->Subwidget("entry");
		$teacherDropEntry->configure( -disabledbackground => "white" );
		$teacherDropEntry->configure( -disabledforeground => "black" );

		$BlockJBE = $db->JBrowseEntry(
			-variable  => \$curBlock,
			-state     => 'readonly',
			-browsecmd => sub {
				my %rHash = reverse %blockName;
				my $id    = $rHash{$curBlock};
				print "Block ID <$id>\n";
				$block = $section->get_block_by_id($id);
				$OKAY->configure(-state=>'normal');
			}
		);
		my $blockDropEntry = $BlockJBE->Subwidget("entry");
		$blockDropEntry->configure( -disabledbackground => "white" );
		$blockDropEntry->configure( -disabledforeground => "black" );

		# -------------------------------------------------------
		# NAME entry widgets
		# -------------------------------------------------------

		$SectionEnt   = $db->Entry( -textvariable => \$newSection );
		$TeacherFName = $db->Entry( -textvariable => \$newFName );
		$TeacherLName = $db->Entry( -textvariable => \$newLName );

		# -------------------------------------------------------
		# button widgets
		# -------------------------------------------------------

		$SectionNew = $db->Button(
			-text    => "CREATE",
			-command => sub {
				add_new_section(
					\$newSection, \$course, \%sectionName,
					\$SectionJBE, \$curSection
				);
			}
		);
		$TeacherNew = $db->Button(
			-text    => "CREATE",
			-command => sub {
				add_new_teacher(
					\$newFName,   \$newLName, \%teacherName,
					\$TeacherJBE, \$curTeach
				);
			}
		);
		$BlockNew = $db->Button(
			-text    => "CREATE",
			-command => sub {
				add_new_block(
					\$section, \%blockName, \$BlockJBE,
					\$curBlock, \$OKAY
				);
			}
		);

		# -------------------------------------------------------
		# Widget Griding
		# -------------------------------------------------------

		$MenuLabel->grid( '-', '-', '-', '-', -sticky => 'nsew' );

		$CourseLabel->grid( $CourseJBE, "-", "-", -sticky => 'nsew' );
		$TeacherLabel->grid(
			$TeacherJBE, $TeacherFName, $TeacherLName,
			$TeacherNew, -sticky => 'nsew'
		);
		$SectionLabel->grid( $SectionJBE, $SectionEnt, "-", $SectionNew,
			-sticky => 'nsew' );
		$BlockLabel->grid( $BlockJBE, "-", "-", $BlockNew, -sticky => 'nsew' );

		#Show menu
		my $answer = $db->Show() || "Cancel";
		print $block;
		if ( $answer eq "OK" ) {
			#if answer is okay, check if a block is defined
			if ($block) {
				#if it is, assign all the properties to the block and return
				$block->day($day);
				$block->start( _hoursToString($start) );
				$block->duration($duration);
				$block->assign_lab($lab);
				$block->assign_teacher($teacher) if $teacher;
				return 1;
			}
		}
		return 0;
	}
}

# ----------------------------------------------------------------------------
# updateSectionList
# When a course is selected, the section menu has to change for the new Course
# ----------------------------------------------------------------------------

sub updateSectionList {

	my $SectionJBE  = ${ +shift };
	my $BlockJBE    = ${ +shift };
	my $course      = shift;
	my $sectionName = shift;
	my $blockName   = shift;
	my $curSection  = shift;
	my $curBlock    = shift;
	my $OKAY = ${+shift};
	
	#Disable okay;
	$OKAY->configure(-state=>'disabled');

	#Blanking the section and block inputs
	$$curSection = "";
	$section     = "";
	$$curBlock   = "";
	$block       = "";

	# Blanking the choice hashes
	%$sectionName = ();
	%$blockName   = ();

	my @sections = $course->sections;

	foreach my $i (@sections) {
		$sectionName->{ $i->id } = "$i";
	}

	# Updating the Drop down with the new options
	$SectionJBE->configure( -choices => $sectionName );
	$BlockJBE->configure( -choices => $blockName );

}

# ----------------------------------------------------------------------------
# updateBlockList
# When a section is selected, the block menu has to change for the new Section
# ----------------------------------------------------------------------------

sub updateBlockList {

	my $BlockJBE  = ${ +shift };
	my $section   = shift;
	my $blockName = shift;
	my $curBlock  = shift;
	my $OKAY = ${+shift};
	
	#Disable okay;
	$OKAY->configure(-state=>'disabled');

	#Blanking the block inputs
	$$curBlock = "";
	$block     = "";

	# Blanking the choice hashes
	%$blockName = ();

	my @blocks = $section->blocks;

	foreach my $i (@blocks) {
		$blockName->{ $i->id } = $i->print_description2;
	}

	# Updating the Drop down with the new options
	$BlockJBE->configure( -choices => $blockName );

}

sub add_new_teacher {

	my $firstname   = shift;
	my $lastname    = shift;
	my $teacherName = shift;
	my $TeacherJBE  = ${ +shift };
	my $curTeach    = shift;

	# Check is a first and last name are inputed, otherwise return
	if ( $$firstname && $$lastname ) {

		#see if a teacher by that name exsits
		my $teacherNew =
		  $Schedule->teachers->get_by_name( $$firstname, $$lastname );

		unless ($teacherNew) {

			#if no teacher by the inputed name exists, create a new teacher
			$teacherNew = Teacher->new(
				-firstname => $$firstname,
				-lastname  => $$lastname
			);
			$$firstname = "";
			$$lastname  = "";
			$Schedule->teachers->add($teacherNew);

			$teacherName->{ $teacherNew->id } = "$teacherNew";
			$TeacherJBE->configure( -choices => $teacherName );
			$$curTeach = "$teacherNew";
			$teacher   = $teacherNew;
		}
		else {
			#If a teacher exists by that name, ask the user if he would like
			#to set that teacher, otherwise return
			my $db = $frame->DialogBox(
				-title   => "Teacher already exists",
				-buttons => [ "Yes", "No" ]
			);
			$db->Label( -text =>
"A teacher by this name already exsists!\nDo you want to set that teacher?"
			)->pack;

			my $answer = $db->Show() || "";
			if ( $answer eq "Yes" ) {
				$$curTeach  = "$teacherNew";
				$$firstname = "";
				$$lastname  = "";
				$teacher    = $teacherNew;
			}
		}
	}

}

sub add_new_section {

	my $name        = shift;
	my $course      = ${ +shift };
	my $sectionName = shift;
	my $SectionJBE  = ${ +shift };
	my $curSection  = shift;

	#check if a course is defined, otherwise return
	if ($course) {

		#check to see if a section by that name  exists
		my @sections = $course->get_section_by_name($$name);
		my $sectionNew;

		unless (@sections) {

			#If it doesn't, create the new section
			$sectionNew = Section->new(
				-number => $course->get_new_number,
				-hours  => 0,
				-name   => $$name
			);
			$$name = "";
			$course->add_section($sectionNew);

			$sectionName->{ $sectionNew->id } = "$sectionNew";
			$SectionJBE->configure( -choices => $sectionName );
			$$curSection = "$sectionNew";
			$section     = $sectionNew;
		}
		else {
			#If a section by the same name does exists
			# ask the user if he want's to create a new section with that name
			my $db = $frame->DialogBox(
				-title   => "Section already exists",
				-buttons => [ "Yes", "No" ]
			);
			$db->Label( -text => scalar @sections
				  . " section(s) by this name already exsist!\nDo you still want create this new section?"
			)->pack;

			my $answer = $db->Show() || "";
			if ( $answer eq "Yes" ) {

				#If he does, create the new section
				$sectionNew = Section->new(
					-number => $course->get_new_number,
					-hours  => 0,
					-name   => $$name
				);
				$$name = "";
				$course->add_section($sectionNew);

				$sectionName->{ $sectionNew->id } = "$sectionNew";
				$SectionJBE->configure( -choices => $sectionName );
				$$curSection = "$sectionNew";
				$section     = $sectionNew;
			}
			else {
				#Otherwise, set section to first instance of the section with
				#the section name
				my $temp = $sections[0];
				$$curSection  = "$temp";
				$$sectionName = "";
				$section      = $temp;
			}
		}
	}

}

sub add_new_block {
	my $section   = ${ +shift };
	my $blockName = shift;
	my $BlockJBE  = ${ +shift };
	my $curBlock  = shift;
	my $OKAY = ${ +shift };

	#If a section is defined, create a new block and set active block to it
	if ($section) {
		my $new = Block->new( -number => $section->get_new_number );
		$blockName->{ $new->id } = $new->print_description2;
		$$curBlock = $new->print_description2;
		$section->add_block($new);
		$BlockJBE->configure( -choices => $blockName );
		$block = $new;
		$OKAY->configure(-state=>'normal');
	}

}

#=======================
#_hoursToString
#  8.5 -> 8:30
#=======================
sub _hoursToString {
	my $time = shift;

	my $string = int($time) . ":";
	$string = $string . "00" if $time == int($time);
	$string = $string . "30" unless $time == int($time);

	return $string;

}

1;
