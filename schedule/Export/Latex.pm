#!/usr/bin/perl
use strict;
use warnings;

package Latex;
use FindBin;
use lib "$FindBin::Bin/..";

use Schedule::Schedule;
use Export::DrawView;

=head1 NAME

Latex - creates Latex schdedule documents

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    # ----------------------------------------------------------
    # create a teacher view latex
    # ----------------------------------------------------------
    
    # get schedule info
    my $Schedule = Schedule->read_YAML('myschedule_file.yaml');
    my $teacher  = $Schedule->teachers()->get_by_name("Sandy","Bultena");

    # create the pdf
    Latex->newView( $Schedule, $teacher, "myViewPDF" );
    

=head1 DESCRIPTION

Provides specific methods for Views and Reports

=cut 

##############################################################################
# INDIVIDUAL LATEX TEMPLATE BITS
##############################################################################

our $object_start_template = <<OBJECT_START_TEMPLATE;

% ---------------------------------------------
\\begin{minipage}{5 in}
\\subsection*{\\myuline{!!!TITLE!!!}}
OBJECT_START_TEMPLATE



our $section_teacher_start_template = <<SECTION_TEACHER_START_TEMPLATE;

\\vspace{-2pt}
\\subsubsection*{!!!SECTION!!!}
\\vspace{-7pt}
\\textbf{!!!TEACHERS!!!}
\\vspace{2pt}

SECTION_TEACHER_START_TEMPLATE


our $teacher_course_template = <<TEACHER_COURSE_TEMPLATE;
\\subsubsection*{!!!COURSE!!!}
TEACHER_COURSE_TEMPLATE



our $section_start_template = <<SECTION_START_TEMPLATE;

\\vspace{-2pt}
\\subsubsection*{!!!SECTION!!!}
\\vspace{-7pt}

SECTION_START_TEMPLATE


our $blocks_start_template = "\\begin{tabular}{l r r l}\n";


our $block_info_template = <<BLOCK_INFO_TEMPLATE;
!!!DAY!!! & !!!START!!!-!!!END!!! & !!!DURATION!!! hours & labs: !!!LABS!!! \\\\
BLOCK_INFO_TEMPLATE


our $block_end_template = "\\end{tabular}\n";


our $object_end_template = <<OBJECT_END_TEMPLATE;
\\\\[12pt]
\\end{minipage}
OBJECT_END_TEMPLATE



# =====================================================================
# create latex of views
# =====================================================================

=head2 newView ($schedule, $schedule_obj, $filename);

Creates a latex for the Schedule for $schedule_obj

B<Parameters>

=over

=item * Schedule

=item * Schedule object (teacher/lab/stream)

=item * Filename to save file as

=back

=cut

sub newView {
    my $class    = shift;
    my $schedule = shift;
    my $obj      = shift;
    my $filename = shift;

    my $self = {};
    bless $self, $class;

    # ------------------------------------------------------------------------
    # read the view template
    # ------------------------------------------------------------------------
    my $template;
    open my $fh, "$FindBin::Bin/Export/template.tex" 
            or die "Cannot find the tex template";
    {
        local undef $/;
        $template = <$fh>;
    }
    close $fh;

    # ------------------------------------------------------------------------
    # write the object info
    # ------------------------------------------------------------------------
    my @parts = split "/", $filename;
    $template =~ s/!!!NAME!!!/$obj/g;
    $template =~ s/!!!FILENAME!!!/$filename/g;
    my $time = scalar(localtime);
    $template =~ s/!!!DATE!!!/$time/g;
    my $email = " ";
    my $info = " ";

    # ------------------------------------------------------------------------
    # add the blocks to the template
    # ------------------------------------------------------------------------
    # get the blocks, which depends on which type of object we have
    my @blocks = ();
    if ( defined $obj ) {
        if ( $obj->isa("Teacher") ) {
            @blocks = $schedule->blocks_for_teacher($obj);
            $email = $obj->firstname . "." . $obj->lastname . "\@johnabbott.qc.ca";
            $info = "phone number";
        }
        elsif ( $obj->isa("Lab") ) {
            @blocks = $schedule->blocks_in_lab($obj);
            $info = "CompSci Laboratory";
        }
        else { @blocks = $schedule->blocks_for_stream($obj); 
            $info = "CompSci Stream";
        }
    }
    $template =~ s/!!!EMAIL!!!/$email/;
    $template =~ s/!!!INFO!!!/$info/;

    my @weekdays =
      (qw(sunday monday tuesday wednesday thursday friday saturday));

    # draw the blocks
    my $text = "";
    
    foreach my $block (@blocks) {

    my $start = $block->start;
    my ($hrs, $min) = split ":",$start;
    my $time = $hrs + $min/60;

        my $btext = DrawView->get_block_text( $block, undef, lc( ref($obj) ) );
        $btext =~ s/\n/ \\\\ /g;
        $btext =~ s/\\\\\s*\\\\/\\\\/g;
        my $tmp =
            "\\node[course={"
          . $block->duration()
          . "}{1}] "
          . "at (\\"
          . $weekdays[ $block->day_number ] . ","
          . $time . ") " . "{"
          . $btext . "};";

        $text = $text . $tmp . "\n";
    }
    $template =~ s/!!!SCHEDULE!!!/$text/;

    # ------------------------------------------------------------------------
    # save the tex file
    # ------------------------------------------------------------------------
    open my $ofh, ">", $filename . ".tex"
      or die "Cannot open latex output file\n";
    $template =~ s/([^\/])_/$1\\_/g;
    print $ofh $template;
    close $ofh;
}


# =====================================================================
# create latex of report
# =====================================================================

=head2 newReport ($schedule, $filename);

Creates a schedule report... useful for giving to registrar's office

B<Parameters>

=over

=item * Schedule

=item * Filename to save file as

=back

=cut

sub newReport {
    my $class    = shift;
    my $schedule = shift;
    my $filename = shift;

    # ------------------------------------------------------------------------
    # read the report template
    # ------------------------------------------------------------------------
    my $template;
    open my $fh, "$FindBin::Bin/Export/template_report.tex" 
    or die "Cannot find the tex template";
    {
        local undef $/;
        $template = <$fh>;
    }
    close $fh;
    my $course_latex  = $template;
    my $teacher_latex = $template;

    # ------------------------------------------------------------------------
    # create a new latex document
    # ------------------------------------------------------------------------
    my $self = {};
    bless $self, $class;

    # ------------------------------------------------------------------------
    # Write courses to latex
    # ------------------------------------------------------------------------
    $course_latex =~ s/!!!TYPE!!!/Courses/;
    $course_latex =~ s/!!!FILENAME!!!/${filename}_courses.tex/;
    $course_latex =~ s/!!!DATE!!!/scalar(localtime)/e;
    
    my @course_texts;

    foreach my $c ( sort { $a->number cmp $b->number } $schedule->all_courses )
    {
        push @course_texts, $self->_write_course_latex($c);
    }

    my $courses_text = join( "\n", @course_texts );
    $course_latex =~ s/!!!CONTENT!!!/$courses_text/;

    # ------------------------------------------------------------------------
    # save the tex file
    # ------------------------------------------------------------------------
    open my $ofh, ">", $filename . "_courses.tex"
      or die "Cannot open latex output file\n";
    $course_latex =~ s/([^\/])_/$1\\_/g;
    print $ofh $course_latex;
    close $ofh;

    # ------------------------------------------------------------------------
    # Write teachers to latex
    # ------------------------------------------------------------------------
    $teacher_latex =~ s/!!!TYPE!!!/Teachers/;
    $teacher_latex =~ s/!!!FILENAME!!!/${filename}_teachers.tex/;
    $teacher_latex =~ s/!!!DATE!!!/scalar(localtime)/e;

    my @teacher_texts;

    foreach my $t ( sort { lc( $a->lastname ) cmp lc( $b->lastname ) }
                    $schedule->all_teachers )
    {
        push @teacher_texts, $self->_write_teacher_pdf( $schedule, $t );
    }
    my $teachers_text = join( "\n", @teacher_texts );
    $teacher_latex =~ s/!!!CONTENT!!!/$teachers_text/;

    # ------------------------------------------------------------------------
    # save the tex file
    # ------------------------------------------------------------------------
    open $ofh, ">", $filename . "_teachers.tex"
      or die "Cannot open latex output file\n";
    $teacher_latex =~ s/([^\/])_/$1\\_/g;
    print $ofh $teacher_latex;
    close $ofh;

}

# =====================================================================
# write course to latex
# =====================================================================

sub _write_course_latex {
    my $self   = shift;
    my $course = shift;
    my $latex  = "";

    # ------------------------------------------------------------------------
    # write the various texts
    # ------------------------------------------------------------------------
    # header
    my $header = $object_start_template;
    $header =~ s/!!!TITLE!!!/$course->number . " " .$course->name/e;
    $latex .= $header;

    # sections
    foreach my $s ( sort { $a->number <=> $b->number } $course->sections ) {
        my $section = $section_teacher_start_template;
        my $name    = $s->name;
        $section =~ s/!!!SECTION!!!/$s/;

        # teachers
        my $plural   = "";
        my @teachers = $s->teachers;
        my $teachers = join( ", ", map { "$_" } $s->teachers );
        $plural = "s" if @teachers > 1;
        $section =~ s/!!!TEACHERS!!!/teacher$plural: $teachers/;

        $latex = $latex . $section;

        # blocks
        my $block_text = $blocks_start_template;
        foreach my $block (
            sort {
                     $a->day_number <=> $b->day_number
                  || $a->start_number <=> $b->start_number
            } $s->blocks
          )
        {
            $block_text = $block_text . $self->_write_block($block);
        }
        $latex .= $block_text . $block_end_template;
    }

    $latex = $latex . $object_end_template;
    return $latex;

}

# =====================================================================
# write block to latex
# =====================================================================
sub _write_block {
    my $self  = shift;
    my $block = shift;
    my $labs = join( ", ", map { "$_" }
                       sort { $a->number cmp $b->number } $block->labs );
    my $tmp = $block_info_template;

    $tmp =~ s/!!!DAY!!!/$block->day/e;
    $tmp =~ s/!!!START!!!/$block->start/e;
    $tmp =~ s/!!!END!!!/$block->end/e;
    $tmp =~ s/!!!DURATION!!!/$block->duration/e;
    $tmp =~ s/!!!LABS!!!/$labs/e;

    return $tmp;
}

# =====================================================================
# write teacher to pdf... do not split between page
# =====================================================================
# returns x,y coordinate of sw corner of content

sub _write_teacher_pdf {

    my $self     = shift;
    my $schedule = shift;
    my $teacher  = shift;

    my $latex = "";

    # ------------------------------------------------------------------------
    # write the various texts
    # ------------------------------------------------------------------------

    # header
    my $header = $object_start_template;
    $header =~ s/!!!TITLE!!!/$teacher->firstname." ".$teacher->lastname/e;
    $latex .= $header;

    # tex gets cranky if there is nothing for the teacher
    my @courses = $schedule->courses_for_teacher($teacher);
    unless (@courses) {
            my $block_text = $blocks_start_template;
            $latex .= $block_text . $block_end_template;
    
    }
    
    # course
    foreach my $course ( sort { lc( $a->number ) cmp lc( $b->number ) }
                         $schedule->courses_for_teacher($teacher) )
    {

        my $text .= $course->number . " " . $course->name;
        my $tmp = $teacher_course_template;
        $tmp =~ s/!!!COURSE!!!/$text/;
        $latex   .= $tmp;

        # sections
        foreach my $s (
                        grep { $_->has_teacher($teacher) }
                        sort { $a->number <=> $b->number } $course->sections
          )
        {
            my $section = $section_start_template;
            my $name    = $s->name;
            $section =~ s/!!!SECTION!!!/$s/;

            $latex = $latex . $section;

            # blocks
            my $block_text = $blocks_start_template;
            foreach my $block (
                sort {
                         $a->day_number <=> $b->day_number
                      || $a->start_number <=> $b->start_number
                } $s->blocks
              )
            {
                $block_text = $block_text . $self->_write_block($block);
            }
            $latex .= $block_text . $block_end_template;
        }

    }
    $latex = $latex . $object_end_template;
    return $latex;
}



1;

