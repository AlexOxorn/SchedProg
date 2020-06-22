#!/usr/bin/perl
use strict;
use warnings;

package PDF;
use FindBin;
use lib "$FindBin::Bin/..";

use PerlLib::PDFDocument;
use Schedule::Schedule;

# =====================================================================
# create pdfs of views
# =====================================================================
sub print_view_for {
    my $class = shift;
    my $schedule = shift;
    my $object = shift;
    use Data::Dumper;print $object,"\n";;
}

1;