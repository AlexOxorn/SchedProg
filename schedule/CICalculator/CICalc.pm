#!/usr/bin/perl
use strict;
use warnings;

package CICalc;
use FindBin;
use Carp;
use lib "$FindBin::Bin/..";
use CICalculator::CIConstants;

# for debugging purposes
my $printflag = 0;
sub debug {
    return unless $printflag;
    print (@_);
}

=head1 NAME

CICalc - calculate the CI for a given teacher

=head1 VERSION

Version 1.00

=head1 SYNOPSIS


=head1 DESCRIPTION

Calculates the CI for a given teacher, 1 for each semester, plus total.

Required information is: teacher name

=head1 METHODS

=cut

my @props = (
    "pes",             # student # * contact hours
    "num_preps",       # number of preps 
    "prep_hours",      # hours / week for prep.  One prep per course
    "hours",           # contact hours per week
    "students",        # total number of students seen in one week
    "ntu_students",    # total number of students in courses over 3 hrs/wk
    "release",         # fraction of full load for release
    "dirty_flag",      # data has changed, need to recalculate
);

my @consts = (
    qw(
      teacher
      )
);

# create the setters / getters
foreach my $prop (@props) {
    no strict;
    *$prop = sub {
        my $self = shift;
        $self->{ -$prop } = shift if @_;
        return $self->{ -$prop };
      }
}

# create getters
foreach my $const (@consts) {
    no strict;
    *$const = sub {
        my $self = shift;
        return $self->{ -$const };
      }
}

# ============================================================================
# new
# ============================================================================

=head2 new (teacher object)

Create a new CICalc object

B<Parameters>

- teacher object

=cut

sub new {
    my $class   = shift;
    my $self    = bless {}, $class;
    my $teacher = shift;

    $self->_reset();

    # set constants
    $self->{-teacher} = $teacher;
    
    return $self;
}

# ============================================================================
# calculate (schedule)
# ============================================================================

=head2 calculate (schedule)
Calculate and return CI for fall and winter, from info in the schedule

	# FOR THE MOMENT... WE ARE ONLY GOING TO CALCULATE ONE SEMESTER
	# AT A TIME, BECAUSE THAT IS WHAT IS HOW THE SCHEDULER IS DEFINED

=cut

sub calculate {
    my $self     = shift;
    my $schedule = shift;
    my @CI       = ();
    my $teacher  = $self->teacher;
    my @courses  = $schedule->allocated_courses_for_teacher($teacher);

    $self->_reset();
    $self->_set_release( $teacher->release );

    debug( "\n\n--------- ",$teacher->firstname," ---------\n" );
    debug( "\nstart list\n" );
    foreach my $course (@courses) {
        debug( $course->number," ",$course->name,"\n"  );
    }
    debug( "end list\n\n" );

    # per course
    foreach my $course (@courses) {
        my $max_prep_hours = 0;

            debug( "*********** ",$course->name,"\n" );

        # per section
        foreach my $section ( $course->sections_for_teacher($teacher) ) {

            my $hours    = $section->get_teacher_allocation($teacher);
            my $students = $section->num_students;
            
            debug( $course->name,", Section: ",$section->number,", hours: ",$hours,"\n" );

            $max_prep_hours =
              $max_prep_hours > $hours ? $max_prep_hours : $hours;

            $self->_add_pes( $hours, $students );
            $self->_add_hours($hours);

        }

        # prep is per course, not per section
        $self->_add_prep($max_prep_hours);

    }

    # return
    my $total = $self->_total;
    debug( "CI $teacher: ",$total,"\n" );
    return sprintf("%7.1f",$total);
}

# ************** PRIVATE *****************************************************

# ============================================================================
# _reset
# ============================================================================
# Set all the appropriate properties to their initial values
# ----------------------------------------------------------------------------
sub _reset {
    my $self = shift;

    foreach my $prop (@props) {
        $self->$prop(0);
    }
}

# ============================================================================
# _set_release  (release fraction of FTE)
# ============================================================================
# Set winter or fall release, as a fraction of 'full time' (FTE) for the
# semester in question
# ----------------------------------------------------------------------------
sub _set_release {
    my $self = shift;
    my $release = shift || 0;
    $self->release($release);
}

# ============================================================================
# _add_prep (hours per section)
# ============================================================================
# how many hours of courses do you need to prep (1 prep per section)
# ----------------------------------------------------------------------------
sub _add_prep {
    my $self  = shift;
    my $hours = shift;
    $self->prep_hours( $self->prep_hours + $hours );
    $self->num_preps( $self->num_preps + 1 );
}

# ============================================================================
# _add_hours (total hours)
# ============================================================================
# how many hours are you teaching per week
# ----------------------------------------------------------------------------
sub _add_hours {
    my $self  = shift;
    my $hours = shift;
    $self->hours( $self->hours + $hours );
}

# ============================================================================
# _add_pes (hours, num students in section)
# ============================================================================
# CI factor based on number of students * contact hours
# ----------------------------------------------------------------------------
sub _add_pes {
    my $self     = shift;
    my $hours    = shift;
    my $students = shift;
    $self->pes( $self->pes + $hours * $students );
    $self->students( $self->students + $students );

    # bonus PES (calculated later) only for course over 3 hrs/week
    # The CI calculator from the union imposes this rule,
    # but it appears that Clara does not

    # if ($hours >= 3) {
    $self->ntu_students( $self->ntu_students + $students );

    # }
}

# ============================================================================
# _total
# ============================================================================
# calculate the total CI
# ----------------------------------------------------------------------------
sub _total {
    my $self = shift;

    # ------------------------------------------------------------------------
    # PES (based on # of students and contact hours)
    # ------------------------------------------------------------------------

    my $CI_student = $self->pes * $PES_FACTOR;
    debug( "PES: ",$self->pes,"\n" );
    debug( "Student factor: ",$CI_student,"\n" );

    # bonus if pes is over 415
    my $surplus = $self->pes - $PES_BONUS_LIMIT;
    my $bonus = $surplus > 0 ? $surplus * $PES_BONUS_FACTOR : 0;
    debug( "bonus PES > 415: $bonus\n" );
    $CI_student += $bonus;

    # another bonus if total number of students is over student_bonus_limit
    # (only for courses over 3 hours)
    debug( "students ",$self->students,"\n" );
    $bonus =
        $self->ntu_students >= $STUDENT_BONUS_LIMIT
      ? $self->ntu_students * $STUDENT_BONUS_FACTOR
      : 0;
     debug( "bonus students over 75: $bonus\n" );
    $CI_student += $bonus;

    # and yet another bonus if number of students is over Crazy student limit
    if ( $self->ntu_students >= $STUDENT_CRAZY_BONUS_LIMIT ) {
        $bonus = ( $self->ntu_students - $STUDENT_CRAZY_BONUS_LIMIT ) *
          $STUDENT_CRAZY_BONUS_FACTOR;
        $CI_student += $bonus;
    }

    # ------------------------------------------------------------------------
    # Preps (based on # of prep hours PER course)
    # ------------------------------------------------------------------------
    my $CI_preps = $self->prep_hours * $PREP_FACTOR;
    debug( "prep hours ",$self->prep_hours,"\n" );
    debug( "CI prep: $CI_preps\n" );

    # bonus if number of preps is the PREP_BONUS_LIMIT
    if ( $self->num_preps == $PREP_BONUS_LIMIT ) {
        $CI_preps += $self->prep_hours * $PREP_BONUS_FACTOR;
        debug( "CI bonus prep: ",$self->prep_hours * $PREP_BONUS_FACTOR,"\n" );
    }

    # more bonus if over the limit
    elsif ( $self->num_preps > $PREP_BONUS_LIMIT ) {
        $CI_preps += $self->prep_hours * $PREP_CRAZY_BONUS_FACTOR;
        debug( "CI bonus bonsu prep: ",$self->prep_hours * $PREP_CRAZY_BONUS_FACTOR,"\n" );
    }

    # ------------------------------------------------------------------------
    # Hours (based on contact hours per week)
    # ------------------------------------------------------------------------
    my $CI_hours = $self->hours * $HOURS_FACTOR;
    debug( "CI hours: $CI_hours\n" );

    # ------------------------------------------------------------------------
    # Release
    # ------------------------------------------------------------------------
    my $CI_release = $self->release * $CI_FTE_PER_SEMESTER;
    debug( "CI release: $CI_release\n" );

    # ------------------------------------------------------------------------
    # all done
    # ------------------------------------------------------------------------
    return $CI_release + $CI_hours + $CI_preps + $CI_student;
}

=head1 AUTHOR

Sandy Bultena

=head1 COPYRIGHT

Copyright (c) 2020, Sandy Bultena

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

1;

__END__

##### ORIGINAL JS CODE FOR GOOGLE SHEETS

// ===================================================================================================
// Calculate CI for all teachers and write result to allocation sheet
// ===================================================================================================
function PopulateCITablesQuicker() {
  
  make_CI_class();
  initialize();
  ui = SpreadsheetApp.getUi();
  TotalPES = 0;

  // LOOP OVER FALL AND WINTER  
  for (var season = 1; season <=2; season++) {

    // set up for fall or winter
    if (season == 2) {
      reset_for_winter();
    }
    
    // get enrollment data
    var enrollment_obj = get_enrollment_data();
    
    // -----------------------------------------------------------------------------
    // loop over each teacher
    // -----------------------------------------------------------------------------
    var numTeachers = teacher_range.getNumRows();
    var numCols = teacher_range.getNumColumns();
    var data = teacher_range.getValues();
    
    for (var teacher_num = teacher_offset; teacher_num < numTeachers; teacher_num++) {
      Logger.log("\n\n===============================================");
      Logger.log("teacher: "+data[teacher_num][0]);
      Logger.log("\n===============================================");
      CI_calc = new CI();
          
      // -----------------------------------------------------------------------------
      // find the course #, number of sections, and hours
      // -----------------------------------------------------------------------------
      for (var course = 1; course < numCols; course++) {
        var hours = data[teacher_num][course];
        
        if (! isNaN(hours) && hours > 0) {
          
          // we found a course... yeah!
          var course_num = data[course_offset][course];
          var sections = data[section_offset][course];
          Logger.log("COURSE: "+course_num);
          
          // if it is a complementary course, then maybe teacher is only teaching one section?
          if (course_num.toString().substring(0,1) == "D" && hours == data[hour_offset][course] ) {
            sections = 1;
          }
          
          // -----------------------------------------------------------------------------
          // update CI total for this teacher
          // -----------------------------------------------------------------------------

          // special case - chair duties
          if (course_num == "CHA") {
            CI_calc.add_chair(hours);
          }
          
          // Calculate CI for regular course
          else {
            
            var students = 0;
            for (var section_num = 1; section_num <= sections; section_num++) {
              if (enrollment_obj[course_num] != null) {
                students = students + enrollment_obj[course_num][section_num];
              }
            }
            Logger.log("num students: "+students);

            // Some error checking
            if (sections < 2 && enrollment_obj[course_num][section_num] > 0) {
              ui.alert("Warning", "In Season "+season+" You only have 1 section, \nbut students in two sections for course "+course_num, 
                       ui.ButtonSet.OK);
            }
            
            // calculate CI
            CI_calc.add_prep(hours/sections);
            
            CI_calc.add_hours(hours);
            CI_calc.add_students(hours/sections,students);
            TotalPES = TotalPES + hours/sections * students;
          
          } 
          
        } // end loop over columns looking for a course
      } // end looping over courses
      
      // -----------------------------------------------------------------------------
      // copy calculated CI to the appropriate place
      // -----------------------------------------------------------------------------
      Alloc_sheet.getRange(PES_row, PES_col).setValue(TotalPES);
      Alloc_sheet.getRange(alloc_row_start+teacher_num,CI_col).setValue(CI_calc.total());
      Alloc_sheet.getRange(update_date_row,update_date_col).setValue("Last Update "+Date());
      Alloc_sheet.getRange(update_date_row,update_date_col).setFontColor("black");
      
    
    } // end loop over each teacher

    
  } 

}

// ===================================================================================================
// get the enrollment data
// ===================================================================================================
function get_enrollment_data () {
  var enrollment = enrollment_range.getValues();
  var numEnrollment = enrollment_range.getNumRows();
  var enrollment_obj = {};
  for (i=0; i<numEnrollment; i++) {
    if (enrollment_obj[enrollment[i][0]] == null) {
      enrollment_obj[enrollment[i][0]] = {};
    }
    // enrollment_obj[course][section]=students
    enrollment_obj[enrollment[i][0]][enrollment[i][1]]= enrollment[i][2]*1.0;
  }
  return enrollment_obj;
}

// ===================================================================================================
// create CI class with all of the methods and properties, etc.
// ===================================================================================================
function make_CI_class () {

  CI = function () {
    this.prep_factor = 0.9;
    this.pes = 0;
    this.release = 0;
    this.prep_hours = 0;
    this.hours = 0;
    this.num_preps = 0;
    this.num_students = 0;
    this.ntu_num_students = 0;
  };


  // -----------------------------------------------------------------------------
  // chair release time
  // -----------------------------------------------------------------------------
  CI.prototype.add_chair = function (hours) {
    this.release = this.release  + this.release+0.1875/3 * hours * 40;
    Logger.log("release "+this.release);
  };

  // -----------------------------------------------------------------------------
  // release time
  // -----------------------------------------------------------------------------
  CI.prototype.add_release = function (FTE) {
    this.release = this.release + this.release * 40;
    Logger.log("release "+this.release);
  };

  // -----------------------------------------------------------------------------
  // how many hours of courses do you need to prep (1 prep per section)
  // -----------------------------------------------------------------------------
  CI.prototype.add_prep = function (hours_per_section) {
    this.prep_hours = this.prep_hours+hours_per_section;
    this.num_preps = this.num_preps+1;
    Logger.log("prep hours "+this.prep_hours);
    Logger.log("prep number "+this.num_preps);
  };

  // -----------------------------------------------------------------------------
  // how many hours are you teaching per week
  // -----------------------------------------------------------------------------
  CI.prototype.add_hours = function (hours) {
    this.hours = this.hours+hours;
    Logger.log("hours "+this.hours);
  };

  // -----------------------------------------------------------------------------
  // CI factor based on number of students
  // -----------------------------------------------------------------------------
  CI.prototype.add_students = function (hours_per_section,total_students) {
    Logger.log("pes "+this.pes+" "+hours_per_section+" "+total_students);
    this.pes = this.pes + hours_per_section*total_students;
  
    this.num_students = this.num_students + total_students;

    // bonus PES (calculated later) only for course over 3 hrs/week
    // The CI calculator from the union imposes this rule, but it appears that Clara does not
    // if (hours_per_section >= 3) {
      this.ntu_num_students = this.ntu_num_students + total_students;
    // }
    Logger.log("pes "+this.pes);
  };

  // ===================================================================================================
  // calculate the total CI
  // ===================================================================================================
  CI.prototype.total = function () {
  
    // -----------------------------------------------------
    // student factor
    // -----------------------------------------------------
    var student_factor = this.pes*0.04 // PES = hours*students
    Logger.log("====================== Calculating total CI ");
    Logger.log("");
    Logger.log("student_factor: "+student_factor);
  
    // bonus if the student factor is over 415
    student_factor = student_factor + Math.max(0,this.pes-415)*0.03;
    Logger.log("bonus student_factor if hours*students*0.04 > 415: "+ Math.max(0,this.pes-415)*0.03);
  
    // another bonus if total number of students is over 75
    if (this.ntu_num_students > 75) {
      student_factor = student_factor+this.ntu_num_students*0.01;
      Logger.log("Bonus student_factor if number of student > 75: "+ this.ntu_num_students*0.01);
    }
  
    // and yet another bonus if number of students is over 160
    if (this.ntu_num_students > 160) {
      Logger.log("Bonus student_factor if number of student > 160: "+ (-160+this.ntu_num_students)*0.1);
      student_factor = student_factor + (-160+this.ntu_num_students)*0.1;
    }
    Logger.log("student_factor: "+student_factor);
  
    // -----------------------------------------------------
    // preparation CI depends on how many preps you have
    // -----------------------------------------------------
    var preparations = 0;
    preparations = this.prep_hours*0.9;  // prep_hours = prep * hours in course
    Logger.log("");
    Logger.log("number of preparations = "+this.num_preps);
    Logger.log("preparations (prep*hours * 0.9): "+preparations);
  
    // bonus if number of preps = 3
    if (this.num_preps > 2 && this.num_preps < 4 ) {
      Logger.log("Bonus if preps is 3 "+ this.prep_hours*0.2);
      preparations = preparations + this.prep_hours*0.2;
      Logger.log("preparations: "+preparations);
    }
    else if (this.num_preps > 3) {
      preparations = preparations + this.prep_hours*1;
      Logger.log("Bonus if preps > 3 "+ this.prep_hours*1);
      
    }
    Logger.log("Total Prep CI: "+this.preparations);
  
    // -----------------------------------------------------
    // hours
    // -----------------------------------------------------
    hours = this.hours * 1.2

    // -----------------------------------------------------
    // -----------------------------------------------------
    Logger.log("release: "+this.release+", preparations: "+preparations+", hours: "+hours+", PES: "+student_factor);
    var total = this.release + preparations + hours + student_factor;
    Logger.log("total "+total);
    return total;
  };

}


// ===================================================================================================
// create GLOBAL variables specifying where things are on the spreadsheet, etc.
// ===================================================================================================
function initialize() {
  
  // -------------------------------------------------------------------------------------------------
  // define rows offsets within the allocation table  
  // -------------------------------------------------------------------------------------------------
  course_offset = 0;
  hour_offset = 2;
  section_offset = 1;
  teacher_offset = 4;
  PES_row = 51;
  PES_col = 3;

  // -------------------------------------------------------------------------------------------------
  // variables describing where things are on the allocation spreadsheet, update as required
  // -------------------------------------------------------------------------------------------------
  fall_release_row = 24;
  winter_release_row = 46;
  release_row = fall_release_row;
  release_col = 2;

  fall_alloc_row_start = 1;
  winter_alloc_row_start = 25;
  alloc_row_start = fall_alloc_row_start;

  winter_CI_col = 23;
  fall_CI_col = 23;
  CI_col = fall_CI_col;

  update_date_col = 2;
  update_date_row = 20;
  
  fall_ci_row = 8;
  winter_ci_row = 30;

 
  
  // -------------------------------------------------------------------------------------------------
  // get the required sheets  
  // -------------------------------------------------------------------------------------------------
  spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  Alloc_sheet = spreadsheet.getActiveSheet();
  if (!(Alloc_sheet)) {
    Alloc_sheet = spreadsheet.getSheets()[0];
  }
  ci_sheet = spreadsheet.getSheetByName("CI Calculator");
  
  // CHANGE: enrollment is now on the allocation Sheet
  enrollment_sheet = Alloc_sheet;

  // -------------------------------------------------------------------------------------------------
  // define the ranges on the appropriate sheets  
  // -------------------------------------------------------------------------------------------------
  fall_enrollement_range = enrollment_sheet.getRange("AF5:AH39");
  winter_enrollement_range = enrollment_sheet.getRange("AI5:AK39");
  enrollment_range = fall_enrollement_range;
  ci_row = fall_ci_row;
  
  fall_teacher_range = Alloc_sheet.getRange("B1:S16");
  winter_teacher_range = Alloc_sheet.getRange("B25:S40");
  teacher_range = fall_teacher_range;
  
 
  
}

// ===================================================================================================
// set the global variables required for the winter session
// ===================================================================================================
function reset_for_winter() {
  teacher_range = winter_teacher_range;
  release_row = winter_release_row;
  enrollment_range = winter_enrollement_range;
  CI_col = winter_CI_col;
  alloc_row_start = winter_alloc_row_start;
  ci_row = winter_ci_row;
}

