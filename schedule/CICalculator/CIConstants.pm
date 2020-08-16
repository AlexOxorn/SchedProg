#!/usr/bin/perl
use strict;
use warnings;

package CICalculator::CIConstants;
require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = (
	qw(
	  $PREP_FACTOR
	  $PREP_BONUS_LIMIT
	  $PREP_BONUS_FACTOR
	  $PREP_CRAZY_BONUS_FACTOR

	  $PES_FACTOR
	  $PES_BONUS_LIMIT
	  $PES_BONUS_FACTOR

	  $STUDENT_BONUS_LIMIT
	  $STUDENT_BONUS_FACTOR
	  $STUDENT_CRAZY_BONUS_LIMIT
	  $STUDENT_CRAZY_BONUS_FACTOR

	  $HOURS_FACTOR
	  
	  $CI_FTE_PER_SEMESTER
	  )
);

our $PREP_FACTOR             = 0.9;
our $PREP_BONUS_LIMIT        = 3.0;
our $PREP_BONUS_FACTOR       = 0.2;    # (1.1 - 0.9)
our $PREP_CRAZY_BONUS_FACTOR = 1.0;    # (1.9 - 0.9)

our $PES_FACTOR       = 0.04;
our $PES_BONUS_LIMIT  = 415;
our $PES_BONUS_FACTOR = 0.03;           # (0.07-0.04)

our $STUDENT_BONUS_LIMIT        = 75;
our $STUDENT_BONUS_FACTOR       = 0.01;
our $STUDENT_CRAZY_BONUS_LIMIT  = 160;
our $STUDENT_CRAZY_BONUS_FACTOR = 0.1;

our $HOURS_FACTOR = 1.2;

our $CI_FTE_PER_SEMESTER = 40;
1;
