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
	$frame     = shift;
	$Schedule  = shift;
	$Dirty_ptr = shift;
	$Colours   = shift;
	$Fonts     = shift;
	my $image_dir = shift;
	$GuiSchedule = shift;

	junk();

}

sub junk {
	if ($Schedule) {

		my $lab      = $Schedule->labs->get(0);
		my $time     = 8;
		my $duration = 1.5;

		my $course;
		my $section;
		my $block;
		my $teacher;

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

		my $db = $frame->DialogBox(
			-title   => "Edit Resource",
			-buttons => [ "OK", "Cancel" ]
		);

		my $CourseLabel  = $db->Label( -text => "Course:" );
		my $TeacherLabel = $db->Label( -text => "Teacher:" );
		my $SectionLabel = $db->Label( -text => "Section:" );
		my $BlockLabel   = $db->Label( -text => "Block:" );

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
					\$SectionJBE, $course, \%sectionName,
					\$curSection, \$curBlock
				);
			}
		);
		$SectionJBE = $db->JBrowseEntry(
			-variable  => \$curSection,
			-state     => 'readonly',
			-browsecmd => sub {
				my %rHash = reverse %sectionName;
				my $id    = $rHash{$curSection};
				$section = $course->get_section_by_id($id);
				print "Section ID <$id>\n";
				updateBlockList( \$BlockJBE, $section, \%blockName,
					\$curBlock );
			}
		);
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
		$BlockJBE = $db->JBrowseEntry(
			-variable  => \$curBlock,
			-state     => 'readonly',
			-browsecmd => sub {
				my %rHash = reverse %blockName;
				my $id    = $rHash{$curBlock};
				print "Block ID <$id>\n";
				$block = $section->get_block_by_id($id);
			}
		);

		$SectionEnt   = $db->Entry( -textvariable => \$newSection );
		$TeacherFName = $db->Entry( -textvariable => \$newFName );
		$TeacherLName = $db->Entry( -textvariable => \$newLName );

		$SectionNew = $db->Button(
			-text    => "ADD NEW",
			-command => sub {
				add_new_section(
					\$newSection, \$course, \%sectionName,
					\$SectionJBE, \$curSection
				);
			}
		);
		$TeacherNew = $db->Button(
			-text    => "ADD NEW",
			-command => sub {
				add_new_teacher(
					\$newFName,   \$newLName, \%teacherName,
					\$TeacherJBE, \$curTeach
				);
			}
		);
		$BlockNew = $db->Button(
			-text    => "ADD NEW",
			-command => sub {
				add_new_block( \$section, \%blockName, \$BlockJBE, \$curBlock );
			}
		);

		$CourseLabel->grid( $CourseJBE, "-", "-", -sticky => 'nsew' );
		$TeacherLabel->grid(
			$TeacherJBE, $TeacherFName, $TeacherLName,
			$TeacherNew, -sticky => 'nsew'
		);
		$SectionLabel->grid( $SectionJBE, $SectionEnt, "-", $SectionNew,
			-sticky => 'nsew' );
		$BlockLabel->grid( $BlockJBE, "-", "-", $BlockNew, -sticky => 'nsew' );

		$db->Show();
	}
}

sub updateSectionList {

	my $SectionJBE  = ${ +shift };
	my $course      = shift;
	my $sectionName = shift;
	my $curSection  = shift;
	my $curBlock    = shift;

	$$curSection = "";
	$$curBlock   = "";

	%$sectionName = ();

	my @sections = $course->sections;

	foreach my $i (@sections) {
		$sectionName->{ $i->id } = "$i";
	}

	$SectionJBE->configure( -choices => $sectionName );

}

sub updateBlockList {

	my $BlockJBE  = ${ +shift };
	my $section   = shift;
	my $blockName = shift;
	my $curBlock  = shift;

	$$curBlock = "";

	%$blockName = ();

	my @blocks = $section->blocks;

	foreach my $i (@blocks) {
		$blockName->{ $i->id } = $i->print_description2;
	}

	$BlockJBE->configure( -choices => $blockName );

}

sub add_new_teacher {

	my $firstname   = shift;
	my $lastname    = shift;
	my $teacherName = shift;
	my $TeacherJBE  = ${ +shift };
	my $curTeach    = shift;

	if ( $$firstname && $$lastname ) {
		my $teacher =
		  $Schedule->teachers->get_by_name( $$firstname, $$lastname );

		unless ($teacher) {
			$teacher = Teacher->new(
				-firstname => $$firstname,
				-lastname  => $$lastname
			);
			$$firstname = "";
			$$lastname  = "";
			$Schedule->teachers->add($teacher);

			$teacherName->{ $teacher->id } = "$teacher";
			$TeacherJBE->configure( -choices => $teacherName );
			$$curTeach = "$teacher";
		}
		else {
			my $db = $frame->DialogBox(
				-title   => "Teacher already exists",
				-buttons => [ "Yes", "No" ]
			);
			$db->Label( -text =>
"A teacher by this name already exsists!\nDo you want to set that teacher?"
			)->pack;

			my $answer = $db->Show() || "";
			if ( $answer eq "Yes" ) {
				$$curTeach  = "$teacher";
				$$firstname = "";
				$$lastname  = "";
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

	if ($course) {
		my @sections = $course->get_section_by_name($$name);
		my $section;

		unless (@sections) {
			$section = Section->new(
				-number => $course->get_new_number,
				-hours  => 0,
				-name   => $$name
			);
			$$name = "";
			$course->add_section($section);

			$sectionName->{ $section->id } = "$section";
			$SectionJBE->configure( -choices => $sectionName );
			$$curSection = "$section";
		}
		else {
			my $db = $frame->DialogBox(
				-title   => "Section already exists",
				-buttons => [ "Yes", "No" ]
			);
			$db->Label( -text => scalar @sections
				  . " section(s) by this name already exsist!\nDo you still want create this new section?"
			)->pack;

			my $answer = $db->Show() || "";
			if ( $answer eq "Yes" ) {
				$section = Section->new(
					-number => $course->get_new_number,
					-hours  => 0,
					-name   => $$name
				);
				$$name = "";
				$course->add_section($section);

				$sectionName->{ $section->id } = "$section";
				$SectionJBE->configure( -choices => $sectionName );
				$$curSection = "$section";
			}
		}
	}

}

sub add_new_block {
	my $section   = ${ +shift };
	my $blockName = shift;
	my $BlockJBE  = ${ +shift };
	my $curBlock  = shift;

	if($section){
		my $new = Block->new( -number => $section->get_new_number );
		$blockName->{ $new->id } = $new->print_description2;
		$$curBlock = $new->print_description2;
		$section->add_block($new);
		$BlockJBE->configure( -choices => $blockName );	
	}

	

}

1;
