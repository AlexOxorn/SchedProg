#!/usr/bin/perl
use strict;
use warnings;

package PDF;
use FindBin;
use lib "$FindBin::Bin/..";

use PerlLib::PDFDocument;
use Schedule::Schedule;
use Export::DrawView;

=head1 NAME

PDF - creates PDF documents

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    # ----------------------------------------------------------
    # create a simple pdf
    # ----------------------------------------------------------
    my $pdf = PDF->new();
    $pdf->createText( $Height/2, $Width/2, 
                      -text    => "hello World",
                      -anchor  => "center",
                      -fill    => "blue",
                      -font    => "title"
                    );
    $pdf->filename("hello");
    $pdf->save();

    # ----------------------------------------------------------
    # create a teacher view pdf
    # ----------------------------------------------------------
    
    # adjust position of view on page
    $PDF::Scale->{-xorg} = 60;
    $PDF::Scale->{-yorg} = 100;
    
    # get schedule info
    my $Schedule = Schedule->read_YAML('myschedule_file.yaml');
    my $teacher  = $Schedule->teachers()->get_by_name("Sandy","Bultena");

    # create the pdf
    PDF->newView( $Schedule, $teacher, "myViewPDF" );
    

=head1 DESCRIPTION

Provides generic PDF routines for text, rectangles and lines.

Provides specific methods for Views and Reports

=head1 COORDINATES

The coordinates used in these methods are the same as what would be used
in Tk::Canvas... in other words, (0,0) is located at the top right
corner of page.

=head1 PACKAGE VARIABLES

=head2 Fonts

Note that Fonts are defined in PDFDocument (... please forgive the mess
of PDFDocument fonts, it was designed for something else entirely).

Fonts MUST be set before creating new PDF object.

C<$PDF::f_head1> default: "explain";

C<$PDF::f_head2>  default:  "smalltext";

C<$PDF::f_bold>  default: "smallestbold";

C<$PDF::f_normal> = default: "smallest";



=head2  Setting size of View drawn with newView 

C<$PDF::Scale> (hash ref)

default:

=over

=item * weekly grid starts at this position (number will be scaled by 
scaling factors I<i>C<org>

=over

C<< -xoff => >> I<int> 

C<< -yoff => >> I<int> 

=back 

=item * the entire diagram starts at this position

=over

C<< -xorg => >> I<int> 

C<< -yorg => >> I<int>

=back 

=item * how much to stretch the diagram horizontally and vertically 
(1 day has a width of 1 before stretching, and 1 hour has a height of 1 before stretching)

=over 

C<< -xscl => >> I<float>

C<< -yscl => >> I<float>

=back

=back

=over

=item * Overall scale... has no affect on the diagram but represents an indication
of how scaled it is to its "natural" size.  Affects what text is written into
the block.  (Less than .75 teachers will be indicated by initials only)

=over

C<< -scale => >> I<float> 

=back

=back

=cut 

our $Width  = 8.5 * 72;    # 8.5 inches, converted to points
our $Height = 11 * 72;     # 11 inches, converted to points
our $Scale = {
           -xoff  => 1,           # before being scaled by xscl
           -yoff  => 1,           # before being scaled by yscl
           -xorg  => 0,           # start drawing at this position
           -yorg  => 100,         # start drawing at this position
           -xscl  => 84,          # stretch horizontally
           -yscl  => 50,          # stretch vertically
           -scale => 1,           # 1 = 100%.  Text may be modified if scale < 1
};

my $Indent = 10;

# fonts to use
our $f_head1  = "explain";
our $f_head2  = "smalltext";
our $f_bold   = "smallestbold";
our $f_normal = "smallest";

# vertical distance between two lines of text
my $base_head1;
my $base_head2;
my $base_bold;
my $base_normal;

# size of of em for this font
my $em_head2;
my $em_bold;
my $em_normal;

=head1 METHODS

=cut

# =====================================================================
# new
# =====================================================================

=head2 new ();

Creates the PDF object to write to. Opens a page.

=cut

our $Ymargin = 40;
our $Xmargin = 60;

sub new {
    my $class = shift;
    my $self  = {};
    bless $self;

    # ------------------------------------------------------------------------
    # create a new pdf document, and new page
    # ------------------------------------------------------------------------
    my $pdf = PDFDocument->new( $Width, $Height );
    $pdf->new_page();
    $self->pdf($pdf);

    # ------------------------------------------------------------------------
    # get info about fonts based on their sizes
    # ------------------------------------------------------------------------
    $base_head1  = $pdf->get_line_height_from_font($f_head1);
    $base_head2  = $pdf->get_line_height_from_font($f_head2);
    $base_bold   = $pdf->get_line_height_from_font($f_bold);
    $base_normal = $pdf->get_line_height_from_font($f_normal);

    # pixels per "em"
    $em_head2  = $pdf->get_font_size($f_head2) / 12.0 * 16;
    $em_bold   = $pdf->get_font_size($f_bold) / 12.0 * 16;
    $em_normal = $pdf->get_font_size($f_normal) / 12.0 * 16;

    $PDFDocument::DEFAULT_FONT = $base_normal;

    return $self;
}

# =====================================================================
# create pdfs of report
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
    my $self     = $class->new();

    # ------------------------------------------------------------------------
    # create a new pdf document, and new page
    # ------------------------------------------------------------------------
    my $pdf = PDFDocument->new( $Width, $Height );
    $pdf->new_page();
    $self->pdf($pdf);

    # ------------------------------------------------------------------------
    # Write courses to pdf
    # ------------------------------------------------------------------------
    my $y = $Ymargin;
    my $x = $Xmargin;

    $self->createText(
                       $x, $y,
                       -text   => "Courses",
                       -anchor => "nw",
                       -font   => $f_head1
    );
    $y = $y + 2 * $base_head1;

    foreach my $c ( sort { $a->number cmp $b->number } $schedule->all_courses )
    {
        ( $x, $y ) = $self->_write_course_pdf( $c, $x, $y );
    }

    # ------------------------------------------------------------------------
    # save the pdf
    # ------------------------------------------------------------------------
    $pdf->filename( $filename . "_courses" );
    $pdf->save();

    # ------------------------------------------------------------------------
    # create a new pdf document, and new page
    # ------------------------------------------------------------------------
    $pdf = PDFDocument->new( $Width, $Height );
    $pdf->new_page();
    $self->pdf($pdf);

    # ------------------------------------------------------------------------
    # Write teachers to pdf
    # ------------------------------------------------------------------------
    $y = $Ymargin;
    $x = $Xmargin;

    $self->createText(
                       $x, $y,
                       -text   => "Teachers",
                       -anchor => "nw",
                       -font   => $f_head1
    );
    $y = $y + 2 * $base_head1;

    foreach my $t ( sort { lc( $a->lastname ) cmp lc( $b->lastname ) }
                    $schedule->all_teachers )
    {
        ( $x, $y ) = $self->_write_teacher_pdf( $schedule, $t, $x, $y );
    }

    # ------------------------------------------------------------------------
    # save the pdf
    # ------------------------------------------------------------------------
    $pdf->filename( $filename . "_teachers" );
    $pdf->save();
}

# =====================================================================
# create pdfs of views
# =====================================================================

=head2 newView ($schedule, $schedule_obj, $filename);

Creates a pdf for the Schedule for $schedule_obj

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
    my $self     = $class->new();

    $PDFDocument::DEFAULT_FONT = "smallest";

    # ------------------------------------------------------------------------
    # create a new pdf document, and new page
    # ------------------------------------------------------------------------
    my $pdf = PDFDocument->new( $Width, $Height );
    $pdf->new_page();
    $self->pdf($pdf);

    # ------------------------------------------------------------------------
    # write the header and the footer
    # ------------------------------------------------------------------------
    $self->createText(
                       $Width / 2, $Scale->{-yorg} / 2,
                       -text => "$obj",
                       -font => "explain"
    );
    $self->createText(
                       20, $Height - 20,
                       -text   => $filename,
                       -anchor => "sw"
    );
    $self->createText(
                       $Width - 20, $Height - 20,
                       -text   => scalar(localtime),
                       -anchor => "se"
    );

    # ------------------------------------------------------------------------
    # Draw the view
    # ------------------------------------------------------------------------

    # draw the background grid
    DrawView->draw_background( $self, $Scale );

    # get the blocks, which depends on which type of object we have
    my @blocks = ();
    if ( defined $obj ) {
        if ( $obj->isa("Teacher") ) {
            @blocks = $schedule->blocks_for_teacher($obj);
        }
        elsif ( $obj->isa("Lab") ) {
            @blocks = $schedule->blocks_in_lab($obj);
        }
        else { @blocks = $schedule->blocks_for_stream($obj); }
    }

    # draw the blocks
    foreach my $block (@blocks) {
        DrawView->draw_block( $self, $block, $Scale, lc( ref($obj) ) );
    }

    # ------------------------------------------------------------------------
    # save the pdf
    # ------------------------------------------------------------------------
    $pdf->filename($filename);
    $pdf->save();
}

# =====================================================================
# pdf getter setter
# =====================================================================

=head2 pdf ($PDFDocument_obj);

Setter / getter for PDFDocument object

=cut

sub pdf {
    my $self = shift;
    $self->{-pdf} = shift if @_;
    return $self->{-pdf};
}

# =====================================================================
# createLine
# =====================================================================

=head2 createLine ( @coords, %options);

Create a Line on the pdf page.

B<Parameters>

=over

=item * coords - a list of x,y pairs specify the line

=item * options ... these options are passed, as is, the PDFDocument::line()

C<-fill> Colour of the line (default black)

C<-dash> Dash patter of the line (default no dash)

C<-width> width of the border of the line (default:1)

=back

=cut

sub createLine {
    my $self   = shift;
    my @coords = ();
    while ( @_ && $_[0] =~ /^\s*[-\d+\.]+\s*$/ ) {
        push @coords, shift;
    }
    my %options = @_;

    @coords = _convert_coords(@coords);
    my $obj;

    # call appropriate sub for this object
    $self->pdf->line( { -coords => \@coords, -options => \%options } );

}

# =====================================================================
# createText
# =====================================================================

=head2 createLine ( @coords, %options);

Write Text on the pdf page.

B<Parameters>

=over

=item * coords - a list of x,y pairs specify the position of the text

=item * options ... these options are passed, as is, the PDFDocument::text()

C<-anchor> where the coords are located relative to the text 
(n, ne, nw, s, se, sw, B<center>) 

C<-justify> if more than one line, the justification of the paragraph 
(B<left>, right, center)

C<-width> width of multiline text, (=0 means not multiline)

C<-margin> page margins

C<-fill> colour of text (default: black)

C<-font> name of font, if named font cannot be found, then replaced with
$PDFDocument::DEFAULT_FONT 

=back

=cut

sub createText {
    my $self    = shift;
    my @coords  = ( shift, shift );
    my %options = @_;

    @coords = _convert_coords(@coords);
    my $obj;

    # call appropriate sub for this object
    $self->pdf->text( { -coords => \@coords, -options => \%options } );
}

# =====================================================================
# createRectangle
# =====================================================================

=head2 createRectangle ( @coords, %options);

Draw Rectangle on pdf

B<Parameters>

=over

=item * coords - two x,y pairs, indicating opposite sides of the rectangle

=item * options ... these options are passed, as is, the PDFDocument::polygon()

C<-fill> colour of internal area of polygon (default: none)

C<-outline> colour of border of polygon (default: black)

C<-width> width of the border of the rectangle (default:0)

=back

=cut

sub createRectangle {
    my $self    = shift;
    my @c       = ( shift, shift, shift, shift );
    my %options = @_;

    @c = _convert_coords(@c);
    my $obj;

    my @coords = ( $c[0], $c[1], $c[0], $c[3], $c[2], $c[3], $c[2], $c[1] );

    # call appropriate sub for this object
    $self->pdf->polygon( { -coords => \@coords, -options => \%options } );
}

# =====================================================================
# convert coords from TkCanvas to pdf
# =====================================================================
sub _convert_coords {
    my @coords = @_;
    my $i      = 0;
    foreach my $c (@coords) {
        if ( $i % 2 ) {
            $c = $Height - $c;
        }
        $i++;
    }
    return @coords;
}

# =====================================================================
# does nothing, just here to make it compatible with Tk::Canvas objects
# =====================================================================
sub createGroup {
    return;
}

# =====================================================================
# write course to pdf... do not split between page
# =====================================================================

sub _write_course_pdf {
    my $self   = shift;
    my $pdf    = $self->pdf;
    my $course = shift;
    my $x      = shift;
    my $y      = shift;

    # ------------------------------------------------------------------------
    # need to calculate the height of the entire course text
    # (no widows)
    # ------------------------------------------------------------------------
    my $height = 0;
    my $text;

    # header
    my $header = $course->number . " " . $course->name;
    $height = $base_head2;

    # sections
    foreach my $s ( sort { $a->number <=> $b->number } $course->sections ) {

        # blank line, section name, teachers
        $height = $base_bold * 2 + $height + $base_normal;

        # blocks (1 line per block)
        my @blocks = $s->blocks;
        $height = $height + scalar(@blocks) * $base_normal;
    }

    if ( $y + $height > $Height - $Ymargin ) {
        $pdf->new_page();
        $y = $Ymargin;
    }

    # ------------------------------------------------------------------------
    # write the various texts
    # ------------------------------------------------------------------------
    # header
    $self->createText(
                       $x, $y,
                       -text   => $course->number . " " . $course->name,
                       -anchor => "nw",
                       -font   => $f_head2
    );
    $y = $y + 0.7 * $base_head2;

    # sections
    foreach my $s ( sort { $a->number <=> $b->number } $course->sections ) {
        $y = $y + $base_bold;
        $self->createText(
                           $x, $y,
                           -text   => "$s",
                           -anchor => "nw",
                           -font   => $f_bold
        );
        $y = $y + $base_bold;

        my $plural   = "";
        my @teachers = $s->teachers;
        $plural = "s" if @teachers > 1;
        my $text = "teacher$plural: " . join( ", ", map { "$_" } $s->teachers );
        $self->createText(
                           $x + $Indent, $y,
                           -text   => $text,
                           -anchor => "nw",
                           -font   => $f_normal
        );
        $y = $y + 1.5 * $base_normal;

        # blocks
        foreach my $block (
            sort {
                     $a->day_number <=> $b->day_number
                  || $a->start_number <=> $b->start_number
            } $s->blocks
          )
        {
            ( $x, $y ) = $self->_write_block( $x, $y, $block );
        }
    }

    return ( $x, $y + 20 );

}

# =====================================================================
# write block to pdf...
# =====================================================================
sub _write_block {
    my $self  = shift;
    my $x     = shift;
    my $y     = shift;
    my $block = shift;

    $self->createText(
                       $x + $Indent, $y,
                       -text   => $block->day,
                       -anchor => "nw",
                       -font   => $f_normal
    );
    
    $self->createText(
                       $x + $Indent + 7 * $em_normal, $y,
                       -text   => $block->start . "-" . $block->end,
                       -anchor => "ne",
                       -font   => $f_normal
    );

    $self->createText(
                       $x + $Indent + 12 * $em_normal, $y,
                       -text   => $block->duration . " hours",
                       -anchor => "ne",
                       -font   => $f_normal
    );

    $self->createText(
                  $x + $Indent + 13 * $em_normal,
                  $y,
                  -text => "labs: "
                    . join( ", ",
                            map    { "$_" }
                              sort { $a->number cmp $b->number } $block->labs ),
                  -anchor => "nw",
                  -font   => $f_normal
    );

    $y = $y + $base_normal;
    return ( $x, $y );
}

# =====================================================================
# write teacher to pdf... do not split between page
# =====================================================================
# returns x,y coordinate of sw corner of content

sub _write_teacher_pdf {
    my $self     = shift;
    my $pdf      = $self->pdf;
    my $schedule = shift;
    my $teacher  = shift;
    my $x        = shift;
    my $y        = shift;

    # ------------------------------------------------------------------------
    # need to calculate the height of the entire teacher text
    # (no widows)
    # ------------------------------------------------------------------------
    my $height = 0;
    my $text;

    # courses
    foreach my $course ( $schedule->courses_for_teacher($teacher) ) {
        $height = $height + $base_head2;

        # sections
        foreach my $s ( grep { $_->has_teacher($teacher) } $course->sections ) {
            $height = 2 * $base_bold;

            # blocks
            my @b = grep { $_->has_teacher($teacher) } $s->blocks;
            $height = scalar(@b) * $base_normal;
        }
    }

    if ( $y + $height > $Height - $Ymargin ) {
        $pdf->new_page();
        $y = $Ymargin;
    }

    # ------------------------------------------------------------------------
    # write the various texts
    # ------------------------------------------------------------------------

    # header
    $self->createText(
                       $x, $y,
                       -text   => "$teacher",
                       -anchor => "nw",
                       -font   => $f_head2
    );
    $y = $y + 0.7 * $base_head2;

    # course
    foreach my $course ( sort { lc( $a->number ) cmp lc( $b->number ) }
                         $schedule->courses_for_teacher($teacher) )
    {

        my $text .= $course->number . " " . $course->name;
        $y = $y + $base_bold;
        $self->createText(
                           $x, $y,
                           -text   => "$text",
                           -anchor => "nw",
                           -font   => $f_bold
        );
        $y = $y + $base_bold;

        # sections
        foreach my $s (
                        grep { $_->has_teacher($teacher) }
                        sort { $a->number <=> $b->number } $course->sections
          )
        {
            $self->createText(
                               $x, $y,
                               -text   => "$s",
                               -anchor => "nw",
                               -font   => $f_bold
            );
            $y = $y + $base_bold;

            # blocks
            foreach my $block (
                sort {
                         $a->day_number <=> $b->day_number
                      || $a->start_number <=> $b->start_number
                } $s->blocks
              )
            {
                ( $x, $y ) = $self->_write_block( $x, $y, $block );
            }
        }
    }

    return ( $x, $y + 20 );

}
1;
