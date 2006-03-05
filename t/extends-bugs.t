#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;
use Test::Exception;

my $module = 'Test::MockObject::Extends';
use_ok( $module ) or exit;

diag( 'RT #17692 - cannot mock inline package without new()' );

{ package InlinePackageNoNew; sub foo; }

lives_ok { Test::MockObject::Extends->new( 'InlinePackageNoNew' ) };
